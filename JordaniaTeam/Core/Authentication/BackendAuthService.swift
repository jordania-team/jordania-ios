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
/// O backend valida o identityToken do provider e retorna access + refresh token.
struct AuthSessionResponse: Decodable, Sendable {
    let token: String
    let userId: UUID
    let name: String?
    let email: String?
    let role: UserRole
    let refreshToken: String
    let refreshExpiresAt: String
}

private struct LoginRequest: Encodable, Sendable {
    let provider: String
    let identityToken: String
    /// nil é omitido do JSON automaticamente — o backend trata ausência como string vazia.
    let name: String?
    /// Nonce original (pré-SHA256). Obrigatório para Apple Sign In.
    let rawNonce: String?
}

private struct RefreshRequest: Encodable, Sendable {
    let refreshToken: String
}

struct CurrentUserResponse: Decodable, Equatable, Sendable {
    let id: UUID
    let email: String?
    let provider: AuthProvider
    let role: UserRole
    let name: String?
}

// MARK: - AuthSession

/// Par (identidade + credenciais) retornado após login/refresh bem-sucedido.
/// Credenciais não integram AuthenticatedUser; vivem isoladas no Keychain.
typealias AuthSession = (user: AuthenticatedUser, credentials: SessionCredentials)

// MARK: - BackendAuthService

/// Responsável exclusivamente pela chamada ao backend de autenticação.
/// Recebe o identityToken do provider (Apple/Google) e retorna AuthSession.
/// Não conhece SessionStore, View ou qualquer outro layer.
///
/// Fronteira de erros: transporte/protocolo lança NetworkError (Core/Networking);
/// rejeição de credenciais lança AuthError (domínio).
struct BackendAuthService: Sendable {

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

        let result = try await execute(request)

        Self.logger.info("POST /auth/login -> HTTP \(result.statusCode)")

        guard (200...299).contains(result.statusCode) else {
            throw mapLoginHTTPError(status: result.statusCode, body: result.body)
        }

        let sessionResponse = try decode(AuthSessionResponse.self, from: result.data)

        Self.logger.info("LoginResponse.token existe? \(!sessionResponse.token.isEmpty)")

        return try authSession(from: sessionResponse)
    }

    func refresh(refreshToken: String) async throws -> AuthSession {
        let result = try await refreshDebug(refreshToken: refreshToken)
        Self.logger.info("POST /auth/refresh -> HTTP \(result.statusCode)")

        guard (200...299).contains(result.statusCode) else {
            if result.statusCode == 401 {
                throw NetworkError.unauthorized
            }
            throw HTTPStatusError(
                requestDescription: "POST /auth/refresh",
                statusCode: result.statusCode,
                body: result.body
            )
        }

        return try authSession(from: decode(AuthSessionResponse.self, from: result.data))
    }

    func refreshDebug(refreshToken: String) async throws -> HTTPDebugResult {
        let url = AppConfiguration.apiBaseURL
            .appendingPathComponent("auth")
            .appendingPathComponent("refresh")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        do {
            request.httpBody = try JSONEncoder().encode(RefreshRequest(refreshToken: refreshToken))
        } catch {
            throw NetworkError.encodingError
        }

        return try await execute(request)
    }

    func logout(accessToken: String) async throws -> HTTPDebugResult {
        let url = AppConfiguration.apiBaseURL
            .appendingPathComponent("auth")
            .appendingPathComponent("logout")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let result = try await execute(request)
        Self.logger.info("POST /auth/logout -> HTTP \(result.statusCode)")
        return result
    }

    func fetchMe(accessToken: String) async throws -> HTTPDecodedResult<CurrentUserResponse> {
        let result = try await fetchMeDebug(accessToken: accessToken)
        Self.logger.info("GET /users/me -> HTTP \(result.statusCode)")

        guard (200...299).contains(result.statusCode) else {
            throw HTTPStatusError(
                requestDescription: "GET /users/me",
                statusCode: result.statusCode,
                body: result.body
            )
        }

        return HTTPDecodedResult(
            statusCode: result.statusCode,
            body: result.body,
            value: try decode(CurrentUserResponse.self, from: result.data)
        )
    }

    func fetchMeDebug(accessToken: String?) async throws -> HTTPDebugResult {
        let url = AppConfiguration.apiBaseURL
            .appendingPathComponent("users")
            .appendingPathComponent("me")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 15

        return try await execute(request)
    }

    // MARK: - Mapping

    private func authSession(from sessionResponse: AuthSessionResponse) throws -> AuthSession {
        guard let refreshExpiresAt = Self.parseDate(sessionResponse.refreshExpiresAt) else {
            Self.logger.error("refreshExpiresAt inválido: \(sessionResponse.refreshExpiresAt, privacy: .public)")
            throw NetworkError.decodingError
        }

        let provider = sessionResponseProvider(from: sessionResponse)
        let user = AuthenticatedUser(
            id: sessionResponse.userId,
            name: sessionResponse.name,
            email: sessionResponse.email,
            provider: provider ?? sessionResponse.tokenProviderFallback,
            role: sessionResponse.role
        )
        let credentials = SessionCredentials(
            accessToken: sessionResponse.token,
            refreshToken: sessionResponse.refreshToken,
            refreshExpiresAt: refreshExpiresAt
        )

        return (user: user, credentials: credentials)
    }

    private func sessionResponseProvider(from response: AuthSessionResponse) -> AuthProvider? {
        response.tokenProviderFallback
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            Self.logger.error("Falha ao decodificar \(String(describing: T.self)): \(error)")
            throw NetworkError.decodingError
        }
    }

    private func execute(_ request: URLRequest) async throws -> HTTPDebugResult {
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

        return HTTPDebugResult(
            statusCode: http.statusCode,
            body: String(data: data, encoding: .utf8),
            data: data
        )
    }

    // MARK: - Error Mapping

    /// 4xx de credencial vira AuthError (domínio); o resto vira NetworkError (protocolo).
    /// O corpo de erro do Spring vai para o log, nunca para a UI.
    private func mapLoginHTTPError(status: Int, body: String?) -> Error {
        let detail = body ?? "<corpo vazio>"
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

    private static func parseDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }
}

struct HTTPDebugResult: Equatable, Sendable {
    let statusCode: Int
    let body: String?
    let data: Data
}

struct HTTPDecodedResult<T> {
    let statusCode: Int
    let body: String?
    let value: T
}

private extension AuthSessionResponse {
    var tokenProviderFallback: AuthProvider {
        guard let provider = JWT.claims(of: token)?.provider else { return .google }
        return AuthProvider(rawValue: provider.lowercased()) ?? .google
    }
}
