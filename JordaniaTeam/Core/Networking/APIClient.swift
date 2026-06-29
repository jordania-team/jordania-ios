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
/// Estratégia de refresh:
/// 1. Proativa: antes de enviar, obtém token via TokenProvider.validAccessToken()
///    que já faz refresh se o access token expira em < 10 min.
/// 2. Reativa: se mesmo assim receber 401, tenta um refresh via TokenProvider.forceRefresh().
/// 3. Terminal: segundo 401 após refresh → signOut() + NetworkError.unauthorized.
///    Sem loop: máximo uma tentativa de refresh por request.
actor APIClient {

    private static let logger = Logger(subsystem: "app.jordania", category: "APIClient")

    private let tokenProvider: TokenProvider
    private let session: URLSession
    private weak var sessionStore: SessionStore?

    init(
        tokenProvider: TokenProvider,
        session: URLSession = .shared,
        sessionStore: SessionStore
    ) {
        self.tokenProvider = tokenProvider
        self.session       = session
        self.sessionStore  = sessionStore
    }

    // MARK: - Public API

    /// Executa um request autenticado com refresh proativo + reativo.
    func perform(_ request: URLRequest) async throws -> Data {
        // Passo 1: obtém token válido (refresh proativo se necessário)
        let token = try await tokenProvider.validAccessToken()
        let authorizedRequest = authorized(request, token: token)

        let (data, response) = try await execute(authorizedRequest)

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        if (200...299).contains(http.statusCode) { return data }

        // Passo 2: 401 inesperado — tenta refresh reativo (coalescido pelo actor)
        if http.statusCode == 401 {
            Self.logger.info("401 recebido — tentando refresh reativo.")

            let newToken = try await tokenProvider.forceRefresh()
            let retryRequest = authorized(request, token: newToken)

            let (retryData, retryResponse) = try await execute(retryRequest)

            guard let retryHTTP = retryResponse as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }

            if (200...299).contains(retryHTTP.statusCode) { return retryData }

            if retryHTTP.statusCode == 401 {
                // Passo 3: segundo 401 — terminal
                Self.logger.error("401 após refresh — sessão inválida, deslogando.")
                await sessionStore?.signOut()
                throw NetworkError.unauthorized
            }

            throw NetworkError.serverError(statusCode: retryHTTP.statusCode)
        }

        throw NetworkError.serverError(statusCode: http.statusCode)
    }

    // MARK: - Private

    private func authorized(_ request: URLRequest, token: String) -> URLRequest {
        var r = request
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return r
    }

    private func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let urlError as URLError {
            Self.logger.error("Erro de transporte: \(urlError)")
            throw NetworkError(from: urlError)
        }
    }
}
