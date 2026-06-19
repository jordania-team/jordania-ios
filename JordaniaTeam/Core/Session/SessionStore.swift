//
//  SessionStore.swift
//  JordaniaTeamA
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
    var isLoading: Bool = false
    var authError: AuthError?

    // MARK: - Dependencies

    private let persistence: SessionPersistence

    // MARK: - Init

    init(persistence: SessionPersistence = SessionPersistence()) {
        self.persistence = persistence
        self.currentUser = persistence.loadSession()
    }

    // MARK: - Computed

    var isSignedIn: Bool {
        currentUser != nil
    }

    // MARK: - Actions

    func signIn(user: AuthenticatedUser, token: String) {
        isLoading = false
        authError = nil
        do {
            try persistence.save(user: user, token: token)
            currentUser = user
        } catch {
            authError = .failed("Não foi possível salvar a sessão com segurança.")
        }
    }

    /// A UI sempre desloga, mesmo se a limpeza do Keychain falhar.
    func signOut() {
        isLoading = false
        currentUser = nil
        authError = nil
        do {
            try persistence.clearAll()
        } catch {
            Self.logger.fault("Logout: falha ao limpar o Keychain — token pode ter persistido.")
        }
    }

    func setError(_ error: AuthError) {
        isLoading = false
        authError = error
    }
}
