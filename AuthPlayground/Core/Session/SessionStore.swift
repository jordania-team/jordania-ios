//
//  SessionStore.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import Foundation
import Observation
import OSLog

/// Fonte única de verdade do estado de autenticação.
/// Delega persistência para SessionPersistence — não conhece Keychain diretamente.
@Observable
@MainActor
final class SessionStore {

    private static let logger = Logger(subsystem: "app.jordania", category: "Session")

    // MARK: - State

    private(set) var currentUser: AuthenticatedUser?
    var isLoading: Bool = false
    var authError: AuthError?

    // MARK: - Dependencies

    /// Não-opcional por design: esquecer a persistência não pode compilar como no-op
    /// silencioso. Para testes/previews, injete um SessionPersistence com Keychain fake.
    private let persistence: SessionPersistence

    // MARK: - Init

    /// Parâmetro opcional apenas para contornar a avaliação nonisolated de default
    /// arguments — a propriedade é non-optional e sempre recebe uma instância real.
    init(persistence: SessionPersistence? = nil) {
        let persistence = persistence ?? SessionPersistence()
        self.persistence = persistence
        self.currentUser = persistence.loadSession()
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
            try persistence.save(user)
            currentUser = user
        } catch {
            authError = .failed("Não foi possível salvar a sessão com segurança.")
        }
    }

    /// A UI sempre desloga, mesmo se a limpeza do Keychain falhar — o usuário nunca
    /// fica preso numa sessão. A falha é logada como evento de segurança.
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
