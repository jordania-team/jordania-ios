//
//  BackendAuthService.swift
//  JordaniaTeamA
//
//  Created by Gabriel Ferrari on 01/06/26.
//

import Foundation
import OSLog

// MARK: - DTOs

/// Resposta de POST /auth/login e POST /auth/refresh.
private struct AuthSessionResponse: Decodable {
    let token: String
    let userId: UUID
    let name: String?
    let email: String?
    let refreshToken: String
    let refreshExpiresAt: Date
}

private struct LoginRequest: Encodable {
    let provider: String
    let identityToken: String
    let name: String?
    let rawNonce: String?
}

private struct RefreshRequest: Encodable {
    let refreshToken: String
}

// MARK: - AuthSession

/// Tripla (identidade + access + refresh) retornada após login ou refresh bem-sucedido.
/// Os tokens não integram AuthenticatedUser — vivem isolados no Keychain.
typealias AuthSession = (user: AuthenticatedUser, accessToken: String, refreshToken: String)

// MARK: - BackendAuthService

/// Responsável pelas chamadas de autenticação ao backend.
/// Não conhece SessionStore, View ou qualquer outro layer.
struct BackendAuthService {

    private static let logger = Logger(subsystem: "app.jordania", category: "BackendAuth")

    nonisolated init() {}

    // MARK: - Login

    func login(
        provider: AuthProvider,
        identityToken: String,
        name: String? = nil,
        rawNonce: String? = nil
    ) async throws -> AuthSession {
        let url = AppConfiguration.apiBaseURL
            .appendingPathComponent("auth")
            .appendingPathComponent("login")

        let body = LoginRequest(
            provider: provider.rawValue,
            identityToken: identityToken,
            name: name,
            rawNonce: rawNonce
        )

        let session: AuthSessionResponse = try await post(to: url, body: body, requiresAuth: false)

        return makeAuthSession(from: session, provider: provider)
    }

    // MARK: - Refresh

    /// Troca o refresh token por um novo par (access + refresh).
    ///
    /// - Throws: `AuthError.sessionExpired` se o backend retornar 401 — erro terminal, não retrytável.
    func refresh(refreshToken: String) async throws -> AuthSession {
        let url = AppConfiguration.apiBaseURL
            .appendingPathComponent("auth")
            .appendingPathComponent("refresh")

        let body = RefreshRequest(refreshToken: refreshToken)

        do {
            let session: AuthSessionResponse = try await post(to: url, body: body, requiresAuth: false)
            return makeAuthSession(from: session, provider: nil)
        } catch NetworkError.unauthorized {
            throw AuthError.sessionExpired
        }
    }

    // MARK: - Logout

    /// Revoga todos os refresh tokens do usuário no servidor.
    /// Best-effort: falhas de rede são logadas mas não impedem o logout local.
    func logout(accessToken: String) async {
        let url = AppConfiguration.apiBaseURL
            .appendingPathComponent("auth")
            .appendingPathComponent("logout")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            _ = try await URLSession.shared.data(for: request)
        } catch {
            Self.logger.warning("Logout remoto falhou (aceito): \(error)")
        }
    }

    // MARK: - Private helpers

    private func post<B: Encodable, R: Decodable>(
        to url: URL,
        body: B,
        requiresAuth: Bool
    ) async throws -> R {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            Self.logger.error("Falha ao codificar request body: \(error)")
            throw NetworkError.encodingError
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            Self.logger.error("Erro de transporte: \(urlError)")
            throw NetworkError(from: urlError)
        }

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw mapHTTPError(status: http.statusCode, data: data)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: str) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Data inválida: \(str)"
            )
        }
        do {
            return try decoder.decode(R.self, from: data)
        } catch {
            Self.logger.error("Falha ao decodificar resposta: \(error)")
            throw NetworkError.decodingError
        }
    }

    private func makeAuthSession(from r: AuthSessionResponse, provider: AuthProvider?) -> AuthSession {
        let user = AuthenticatedUser(
            id: r.userId,
            name: r.name,
            email: r.email,
            provider: provider ?? .apple
        )
        return (user: user, accessToken: r.token, refreshToken: r.refreshToken)
    }

    private func mapHTTPError(status: Int, data: Data) -> Error {
        let detail = String(data: data, encoding: .utf8) ?? "<corpo vazio>"
        Self.logger.error("Request falhou com status \(status): \(detail, privacy: .private)")

        switch status {
        case 401, 403: return NetworkError.unauthorized
        case 400, 422: return AuthError.failed("Dados inválidos. Tente novamente.")
        default:       return NetworkError.serverError(statusCode: status)
        }
    }
}
