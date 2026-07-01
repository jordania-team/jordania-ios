//
//  SessionStore.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import Foundation
import Observation
import OSLog

/// Fonte única de verdade do estado de autenticação.
/// Delega persistência para SessionPersistence — não conhece Keychain diretamente.
/// O JWT nunca é exposto em propriedades observáveis — a UI não precisa dele.
@Observable
@MainActor
final class SessionStore {

    private static let logger = Logger(subsystem: "app.jordania", category: "Session")

    // MARK: - State

    private(set) var currentUser: AuthenticatedUser?
    private(set) var state: SessionState = .loading

    // MARK: - Dependencies

    private let persistence: SessionPersistence

    // MARK: - Init

    init(persistence: SessionPersistence = SessionPersistence()) {
        self.persistence = persistence
        let saved = persistence.loadSession()
        self.currentUser = saved
        self.state = saved != nil ? .authenticated : .signedOut
    }

    // MARK: - Actions

    func signIn(user: AuthenticatedUser, accessToken: String, refreshToken: String) {
        do {
            try persistence.save(user: user, accessToken: accessToken, refreshToken: refreshToken)
            currentUser = user
            state = .authenticated
        } catch {
            state = .error("Não foi possível salvar a sessão com segurança.")
        }
    }

    /// A UI sempre desloga, mesmo se a limpeza do Keychain falhar.
    func signOut() {
        currentUser = nil
        state = .signedOut
        do {
            try persistence.clearAll()
        } catch {
            Self.logger.fault("Logout: falha ao limpar o Keychain — token pode ter persistido.")
        }
    }

    func validateSession(using userService: UserService) async {
        guard currentUser != nil else { return }

        do {
            let freshUser = try await userService.fetchCurrentUser()
            currentUser = freshUser
            state = .authenticated
        } catch NetworkError.unauthorized {
            signOut()
        } catch {
            Self.logger.warning("Validação de sessão falhou — mantendo estado local: \(error)")
            // Mantém .authenticated para não deslogar o usuário por falha de rede
        }
    }

    func retry(using userService: UserService) async {
        state = .loading
        await validateSession(using: userService)
    }
}
