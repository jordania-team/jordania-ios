//
//  SessionStore.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import Foundation
import Observation

/// Fonte única de verdade do estado de autenticação.
/// Observada pela UI via @Environment. Nunca acessa providers diretamente.
@Observable
final class SessionStore {

    // MARK: - State

    var currentUser: AuthenticatedUser?
    var isLoading: Bool = false
    var authError: AuthError?

    // MARK: - Computed

    var isSignedIn: Bool {
        currentUser != nil
    }

    // MARK: - Actions

    func signIn(with user: AuthenticatedUser) {
        currentUser = user
        authError = nil
    }

    func signOut() {
        currentUser = nil
        authError = nil
    }

    func setError(_ error: AuthError) {
        authError = error
        isLoading = false
    }
}

// MARK: - AuthError

enum AuthError: LocalizedError {
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return nil // cancelamento não é erro do ponto de vista do usuário
        case .failed(let message):
            return message
        }
    }
}
