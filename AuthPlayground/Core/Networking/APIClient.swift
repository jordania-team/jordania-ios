//
//  APIClient.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 16/06/26.
//

import Foundation
import OSLog

/// Ponto único de execução de requests HTTP autenticados.
///
/// Responsabilidades:
/// - Lê o JWT do Keychain e injeta no header Authorization antes de cada request
/// - Em 401: tenta refresh uma vez; em falha, desloga via SessionStore
/// - Nunca expõe o token para features ou ViewModels
///
/// Não é usado no login inicial — BackendAuthService faz o bootstrap da sessão.
/// Todos os services de feature (ex: TarefaService) devem usar este cliente.
actor APIClient {

    private static let logger = Logger(subsystem: "app.jordania", category: "APIClient")

    private let keychain: KeychainService
    private let session: URLSession
    private weak var sessionStore: SessionStore?

    // Barreira contra refresh concorrente: apenas uma tentativa de refresh por vez.
    // Se duas chamadas simultâneas recebem 401, apenas uma executa o refresh —
    // a outra aguarda o resultado.
    private var refreshTask: Task<String, Error>?

    init(
        keychain: KeychainService,
        session: URLSession = .shared,
        sessionStore: SessionStore
    ) {
        self.keychain = keychain
        self.session = session
        self.sessionStore = sessionStore
    }

    // MARK: - Public API

    /// Executa um request autenticado com interceptação de 401.
    ///
    /// Uso nos services de feature:
    /// ```swift
    /// let data = try await apiClient.perform(request)
    /// let tarefas = try JSONDecoder().decode([Tarefa].self, from: data)
    /// ```
    func perform(_ request: URLRequest) async throws -> Data {
        let authorizedRequest = try authorizedRequest(from: request)

        let (data, response) = try await execute(authorizedRequest)

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        if (200...299).contains(http.statusCode) {
            return data
        }

        if http.statusCode == 401 {
            Self.logger.info("401 recebido — tentando refresh do token.")
            let newToken = try await refreshToken()

            var retryRequest = request
            retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")

            let (retryData, retryResponse) = try await execute(retryRequest)

            guard let retryHTTP = retryResponse as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            if (200...299).contains(retryHTTP.statusCode) {
                return retryData
            }

            if retryHTTP.statusCode == 401 {
                Self.logger.error("401 após refresh — sessão inválida, deslogando.")
                await sessionStore?.signOut()
                throw NetworkError.unauthorized
            }

            throw NetworkError.serverError(statusCode: retryHTTP.statusCode)
        }

        throw NetworkError.serverError(statusCode: http.statusCode)
    }

    // MARK: - Private

    private func authorizedRequest(from request: URLRequest) throws -> URLRequest {
        guard let token = keychain.loadToken() else {
            Self.logger.error("Token ausente no Keychain ao montar request autenticado.")
            throw NetworkError.unauthorized
        }
        var authorized = request
        authorized.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return authorized
    }

    private func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let urlError as URLError {
            Self.logger.error("Erro de transporte: \(urlError)")
            throw NetworkError(from: urlError)
        }
    }

    private func refreshToken() async throws -> String {
        if let existing = refreshTask {
            Self.logger.info("Refresh já em curso — aguardando resultado.")
            return try await existing.value
        }

        let task = Task<String, Error> {
            defer { refreshTask = nil }
            return try await executeRefresh()
        }
        refreshTask = task
        return try await task.value
    }

    /// ⚠️ PONTO DE INTEGRAÇÃO — implementar quando o backend definir o endpoint de refresh.
    ///
    /// Contrato esperado:
    /// - POST /auth/refresh
    /// - Header: Authorization: Bearer <access_token_atual>
    ///   OU body: { "refreshToken": "..." } — confirmar via OpenAPI
    /// - Response: { "token": "novo_jwt" }
    ///
    /// Por ora lança `.unauthorized` para forçar logout — comportamento seguro por padrão.
    private func executeRefresh() async throws -> String {
        // TODO: implementar quando /auth/refresh estiver no contrato OpenAPI
        Self.logger.error("Refresh não implementado — endpoint /auth/refresh pendente de contrato.")
        throw NetworkError.unauthorized
    }
}
