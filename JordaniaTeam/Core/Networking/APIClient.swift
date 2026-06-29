//
//  APIClient.swift
//  JordaniaTeamA
//
//  Created by Gabriel Ferrari on 16/06/26.
//

import Foundation
import OSLog

/// Ponto único de execução de requests HTTP autenticados.
///
/// Responsabilidades:
/// - Lê credenciais do Keychain e injeta access token antes de cada request
/// - Em access expirado ou 401: tenta refresh, salva novo par e repete uma vez
/// - Nunca expõe o token para features ou ViewModels
///
/// Não é usado no login inicial — BackendAuthService faz o bootstrap da sessão.
/// Todos os services de feature autenticados devem usar este cliente.
actor APIClient {

    private static let logger = Logger(subsystem: "app.jordania", category: "APIClient")

    private let keychain: KeychainService
    private let session: URLSession
    private let backendAuthService: BackendAuthService
    private weak var sessionStore: SessionStore?
    private var refreshTask: Task<SessionCredentials, Error>?

    init(
        keychain: KeychainService,
        session: URLSession = .shared,
        backendAuthService: BackendAuthService = BackendAuthService(),
        sessionStore: SessionStore
    ) {
        self.keychain = keychain
        self.session = session
        self.backendAuthService = backendAuthService
        self.sessionStore = sessionStore
    }

    // MARK: - Public API

    /// Executa um request autenticado com interceptação de 401.
    ///
    /// Uso nos services de feature:
    /// ```swift
    /// let data = try await apiClient.perform(request)
    /// let value = try JSONDecoder().decode(Response.self, from: data)
    /// ```
    func perform(_ request: URLRequest) async throws -> Data {
        let result = try await performDebug(request)

        if (200...299).contains(result.statusCode) {
            return result.data
        }

        if result.statusCode == 401 {
            throw NetworkError.unauthorized
        }

        let error = HTTPStatusError(
            requestDescription: requestLabel(request),
            statusCode: result.statusCode,
            body: result.body
        )
        Self.logger.error("\(error.debugMessage, privacy: .public)")
        throw error
    }

    func performDebug(_ request: URLRequest) async throws -> HTTPDebugResult {
        let authorizedRequest = try await authorizedRequest(from: request, refreshReason: "refresh preventivo")
        let result = try await executeDebug(authorizedRequest)

        Self.logger.info("\(self.requestLabel(authorizedRequest), privacy: .public) -> HTTP \(result.statusCode)")

        guard result.statusCode == 401 else {
            return result
        }

        Self.logger.error("\(self.requestLabel(authorizedRequest), privacy: .public) -> HTTP 401, tentando refresh. Body: \(result.body ?? "<vazio>", privacy: .public)")
        await recordEvent("request 401: \(requestLabel(authorizedRequest)); trying refresh")
        let refreshed = try await refreshCredentials(reason: "refresh por 401")
        var retry = request
        retry.setValue("Bearer \(refreshed.accessToken)", forHTTPHeaderField: "Authorization")

        let retryResult = try await executeDebug(retry)
        Self.logger.info("\(self.requestLabel(retry), privacy: .public) retry -> HTTP \(retryResult.statusCode)")
        await recordEvent("retry: \(requestLabel(retry)) -> HTTP \(retryResult.statusCode)")

        if retryResult.statusCode == 401 {
            await recordEvent("retry still 401: clearing session")
            await signOut()
        }

        return retryResult
    }

    // MARK: - Private

    private func authorizedRequest(from request: URLRequest, refreshReason: String) async throws -> URLRequest {
        var credentials = try await currentCredentials(orSignOutFor: request)

        if credentials.isAccessExpired {
            Self.logger.info("\(self.requestLabel(request), privacy: .public) -> access token expirado localmente; tentando refresh.")
            await recordEvent("access expired before \(requestLabel(request)); trying refresh")
            credentials = try await refreshCredentials(reason: refreshReason)
        }

        var authorized = request
        authorized.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        return authorized
    }

    private func currentCredentials(orSignOutFor request: URLRequest) async throws -> SessionCredentials {
        guard let credentials = keychain.loadCredentials() else {
            Self.logger.error("\(self.requestLabel(request), privacy: .public) -> não enviada: credenciais ausentes no Keychain.")
            await recordEvent("missing credentials before \(requestLabel(request)); clearing session")
            await signOut()
            throw NetworkError.unauthorized
        }

        guard !credentials.isRefreshExpired else {
            Self.logger.error("\(self.requestLabel(request), privacy: .public) -> refresh token expirado.")
            await recordEvent("refresh expired before \(requestLabel(request)); clearing session")
            await signOut()
            throw NetworkError.unauthorized
        }

        return credentials
    }

    private func refreshCredentials(reason: String) async throws -> SessionCredentials {
        if let refreshTask {
            await recordEvent("\(reason): waiting for refresh in progress")
            return try await refreshTask.value
        }

        guard let currentCredentials = keychain.loadCredentials() else {
            await signOut()
            throw NetworkError.unauthorized
        }

        guard !currentCredentials.isRefreshExpired else {
            await recordEvent("\(reason): refresh token expired; clearing session")
            await signOut()
            throw NetworkError.unauthorized
        }

        let oldRefreshMasked = currentCredentials.maskedRefreshToken
        let service = backendAuthService
        let task = Task {
            let session = try await service.refresh(refreshToken: currentCredentials.refreshToken)
            return session.credentials
        }
        refreshTask = task

        do {
            let credentials = try await task.value
            try keychain.saveCredentials(credentials)
            refreshTask = nil
            try await sessionStore?.updateCredentials(
                credentials,
                event: "\(reason): \(oldRefreshMasked) -> \(credentials.maskedRefreshToken)"
            )
            return credentials
        } catch {
            refreshTask = nil
            await recordEvent("\(reason): failed with \(String(describing: error))")
            if case NetworkError.unauthorized = error {
                await signOut()
            }
            throw error
        }
    }

    private func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let urlError as URLError {
            Self.logger.error("Erro de transporte: \(urlError)")
            throw NetworkError(from: urlError)
        }
    }

    private func executeDebug(_ request: URLRequest) async throws -> HTTPDebugResult {
        let (data, response) = try await execute(request)
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        return HTTPDebugResult(
            statusCode: http.statusCode,
            body: responseBody(from: data),
            data: data
        )
    }

    private func signOut() async {
        if let sessionStore {
            await sessionStore.signOut()
        }
    }

    private func recordEvent(_ event: String) async {
        if let sessionStore {
            await sessionStore.recordAuthEvent(event)
        }
    }

    private func requestLabel(_ request: URLRequest) -> String {
        let method = request.httpMethod ?? "HTTP"
        let path = request.url?.path ?? "<sem path>"
        return "\(method) \(path)"
    }

    private func responseBody(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
