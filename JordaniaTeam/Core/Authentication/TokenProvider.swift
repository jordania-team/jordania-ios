//
//  TokenProvider.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 23/06/26.
//

import Foundation
import OSLog

/// Ponto central de fornecimento de access tokens para o APIClient.
///
/// Responsabilidades:
/// - Refresh proativo: detecta que o access token expira em < 10 min e renova antes de falhar
/// - Coalescing: se várias chamadas simultâneas precisarem de refresh, apenas uma Task é criada
///   e as demais aguardam o mesmo resultado — evita condições de corrida e refreshes duplos
/// - Delega estado de sessão para SessionStore via signOut() — não toma decisões de UI
actor TokenProvider {

    private static let logger = Logger(subsystem: "app.jordania", category: "TokenProvider")

    private let persistence: any SessionPersistenceProtocol
    private let authService: any BackendAuthServiceProtocol
    private weak var sessionStore: SessionStore?

    /// Task de refresh em curso; nil quando nenhum refresh está ativo.
    private var refreshTask: Task<String, Error>?

    init(
        persistence: any SessionPersistenceProtocol = SessionPersistence(),
        authService: any BackendAuthServiceProtocol = BackendAuthService(),
        sessionStore: SessionStore
    ) {
        self.persistence  = persistence
        self.authService  = authService
        self.sessionStore = sessionStore
    }

    // MARK: - Public API

    /// Retorna um access token válido, fazendo refresh proativo se necessário.
    ///
    /// Chamado pelo APIClient antes de cada request. Se o token ainda tem mais de
    /// 10 minutos de vida, retorna imediatamente sem rede.
    func validAccessToken() async throws -> String {
        guard let access = persistence.loadAccessToken() else {
            Self.logger.error("Access token ausente no Keychain.")
            throw NetworkError.unauthorized
        }

        guard JWT.needsRefresh(access) else {
            return access
        }

        Self.logger.info("Access token próximo da expiração — disparando refresh proativo.")
        return try await performRefresh()
    }

    /// Refresh reativo: chamado pelo APIClient após receber um 401 inesperado.
    /// Também coalescido — se já há um refresh proativo em voo, aguarda o mesmo resultado.
    func forceRefresh() async throws -> String {
        Self.logger.info("Refresh forçado após 401.")
        return try await performRefresh()
    }

    // MARK: - Private

    private func performRefresh() async throws -> String {
        if let existing = refreshTask {
            Self.logger.info("Refresh já em curso — aguardando resultado coalescido.")
            return try await existing.value
        }

        let task = Task<String, Error> { [weak self] in
            guard let self else { throw NetworkError.unauthorized }
            defer { Task { await self.clearRefreshTask() } }
            return try await self.executeRefresh()
        }
        refreshTask = task
        return try await task.value
    }

    private func clearRefreshTask() {
        refreshTask = nil
    }

    private func executeRefresh() async throws -> String {
        guard let refreshToken = persistence.loadRefreshToken() else {
            Self.logger.error("Refresh token ausente no Keychain — deslogando.")
            await sessionStore?.signOut()
            throw NetworkError.unauthorized
        }

        do {
            let session = try await authService.refresh(refreshToken: refreshToken)
            try persistence.save(
                user: session.user,
                accessToken: session.accessToken,
                refreshToken: session.refreshToken
            )
            Self.logger.info("Refresh concluído com sucesso.")
            return session.accessToken
        } catch AuthError.sessionExpired {
            Self.logger.error("Refresh rejeitado pelo backend — deslogando.")
            await sessionStore?.signOut()
            throw NetworkError.unauthorized
        }
    }
}
