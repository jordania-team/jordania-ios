//
//  BackendAuthService.swift
//  JordaniaTeamA
//
//  Created by Gabriel Ferrari on 01/06/26.
//

import Foundation
import OSLog

// MARK: - DTOs

/// Resposta do endpoint POST /auth/login.
/// O backend valida o identityToken do provider e retorna o JWT interno + dados do usuário.
private struct AuthSessionResponse: Decodable {
    let token: String
    let userId: UUID
    let name: String?
    let email: String?
}

private struct LoginRequest: Encodable {
    let provider: String
    let identityToken: String
    /// nil é omitido do JSON automaticamente — o backend trata ausência como string vazia.
    let name: String?
    /// Nonce original (pré-SHA256). Obrigatório para Apple Sign In.
    let rawNonce: String?
}

// MARK: - AuthSession

/// Par (identidade + token) retornado após login bem-sucedido.
/// O token não integra AuthenticatedUser — vive isolado no Keychain,
/// lido exclusivamente pelo APIClient no momento de cada request.
typealias AuthSession = (user: AuthenticatedUser, token: String)

// MARK: - BackendAuthService

/// Responsável exclusivamente pela chamada ao backend de autenticação.
/// Recebe o identityToken do provider (Apple/Google) e retorna AuthSession.
/// Não conhece SessionStore, View ou qualquer outro layer.
///
/// Fronteira de erros: transporte/protocolo lança NetworkError (Core/Networking);
/// rejeição de credenciais lança AuthError (domínio).
struct BackendAuthService {

    private static let logger = Logger(subsystem: "app.jordania", category: "BackendAuth")
    
    nonisolated init() {}

    // MARK: - Public API

    /// Troca o identityToken do provider por uma sessão autenticada no backend.
    ///
    /// - Parameters:
    ///   - provider: O provider OAuth usado (.apple ou .google)
    ///   - identityToken: O JWT emitido pelo provider (Apple: identityToken, Google: idToken)
    ///   - name: Nome do usuário — obrigatório apenas no primeiro login com Apple
    ///   - rawNonce: Nonce original (pré-SHA256) — obrigatório para Apple, nil para Google
    func login(
        provider: AuthProvider,
        identityToken: String,
        name: String? = nil,
        rawNonce: String? = nil
    ) async throws -> AuthSession {
        let url = AppConfiguration.apiBaseURL
            .appendingPathComponent("auth")
            .appendingPathComponent("login")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body = LoginRequest(
            provider: provider.rawValue,
            identityToken: identityToken,
            name: name,
            rawNonce: rawNonce
        )

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            Self.logger.error("Falha ao codificar LoginRequest: \(error)")
            throw NetworkError.encodingError
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            Self.logger.error("Erro de transporte no login: \(urlError)")
            throw NetworkError(from: urlError)
        }

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw mapHTTPError(status: http.statusCode, data: data)
        }

        let sessionResponse: AuthSessionResponse
        do {
            sessionResponse = try JSONDecoder().decode(AuthSessionResponse.self, from: data)
        } catch {
            Self.logger.error("Falha ao decodificar AuthSessionResponse: \(error)")
            throw NetworkError.decodingError
        }

        let user = AuthenticatedUser(
            id: sessionResponse.userId,
            name: sessionResponse.name,
            email: sessionResponse.email,
            provider: provider
        )

        return (user: user, token: sessionResponse.token)
    }

    // MARK: - Error Mapping

    /// 4xx de credencial vira AuthError (domínio); o resto vira NetworkError (protocolo).
    /// O corpo de erro do Spring vai para o log, nunca para a UI.
    private func mapHTTPError(status: Int, data: Data) -> Error {
        let detail = String(data: data, encoding: .utf8) ?? "<corpo vazio>"
        Self.logger.error("Login falhou com status \(status): \(detail, privacy: .private)")

        switch status {
        case 401, 403:
            return AuthError.failed("Não foi possível validar suas credenciais. Tente novamente.")
        case 400, 422:
            return AuthError.failed("Dados de login inválidos. Tente novamente.")
        default:
            return NetworkError.serverError(statusCode: status)
        }
    }
}
