//
//  SessionPersistence.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import Foundation

/// Responsável exclusivamente por ler e escrever a sessão via Keychain.
/// A SessionStore delega persistência para cá, sem conhecer Security framework diretamente.
/// SwiftData foi removido — tokens JWT nunca devem ser persistidos em banco de dados local.
@MainActor
final class SessionPersistence {

    private let keychain: KeychainService

    init(keychain: KeychainService = KeychainService()) {
        self.keychain = keychain
    }

    // MARK: - Public API

    /// Retorna a sessão persistida no Keychain, se existir.
    func loadSession() -> AuthenticatedUser? {
        keychain.load()
    }

    /// Persiste a sessão do usuário autenticado no Keychain.
    func save(_ user: AuthenticatedUser) throws {
        try keychain.save(user)
    }

    /// Remove a sessão do Keychain.
    func clearAll() {
        keychain.clear()
    }
}
