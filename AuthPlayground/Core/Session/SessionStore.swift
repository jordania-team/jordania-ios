//
//  SessionStore.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import Foundation
import Observation

/// Fonte única de verdade do estado de autenticação.
/// Delega persistência para SessionPersistence — não conhece Keychain ou SwiftData diretamente.
@Observable
@MainActor
final class SessionStore {

    // MARK: - State

    private(set) var currentUser: AuthenticatedUser?
    var isLoading: Bool = false
    var authError: AuthError?

    // MARK: - Dependencies

    private let persistence: SessionPersistence?

    // MARK: - Init

    init(persistence: SessionPersistence? = nil) {
        self.persistence = persistence
        self.currentUser = persistence?.loadSession()
    }

    // MARK: - Computed

    var isSignedIn: Bool {
        currentUser != nil
    }

    // MARK: - Actions

    func signIn(with user: AuthenticatedUser) {
        isLoading = false
        authError = nil
        do {
            try persistence?.save(user)
            currentUser = user
        } catch {
            authError = .failed("Não foi possível salvar a sessão com segurança.")
        }
    }

    func signOut() {
        isLoading = false
        currentUser = nil
        authError = nil
        persistence?.clearAll()
    }

    func setError(_ error: AuthError) {
        isLoading = false
        authError = error
    }
}

// MARK: - AuthError

enum AuthError: LocalizedError {
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return nil
        case .failed(let message):
            return message
        }
    }
}
