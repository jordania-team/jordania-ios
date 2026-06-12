//
//  SessionPersistence.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import Foundation

/// Responsável exclusivamente por ler e escrever a sessão via Keychain.
/// A SessionStore delega persistência para cá, sem conhecer Security framework diretamente.
@MainActor
final class SessionPersistence {

    private let keychain: KeychainService

    init(keychain: KeychainService = KeychainService()) {
        self.keychain = keychain
    }

    // MARK: - Public API

    /// Retorna a sessão persistida, se existir e o token ainda for válido.
    /// Sessão expirada é removida do Keychain — o usuário fará login novamente.
    func loadSession() -> AuthenticatedUser? {
        guard let user = keychain.load() else { return nil }
        guard !JWT.isExpired(user.accessToken) else {
            try? keychain.clear()
            return nil
        }
        return user
    }

    /// Persiste a sessão do usuário autenticado no Keychain.
    func save(_ user: AuthenticatedUser) throws {
        try keychain.save(user)
    }

    /// Remove a sessão do Keychain.
    func clearAll() throws {
        try keychain.clear()
    }
}
