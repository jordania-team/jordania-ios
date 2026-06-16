//
//  SessionPersistence.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import Foundation

/// Responsável exclusivamente por ler e escrever sessão e JWT via Keychain.
/// A SessionStore delega persistência para cá, sem conhecer Security framework diretamente.
final class SessionPersistence {

    private let keychain: KeychainService

    init(keychain: KeychainService = KeychainService()) {
        self.keychain = keychain
    }

    // MARK: - Public API

    /// Retorna a sessão persistida se o token ainda for válido.
    /// Token expirado remove tudo do Keychain — o usuário fará login novamente.
    func loadSession() -> AuthenticatedUser? {
        guard let user = keychain.loadSession() else { return nil }
        guard let token = keychain.loadToken(), !JWT.isExpired(token) else {
            try? keychain.clearAll()
            return nil
        }
        return user
    }

    func save(user: AuthenticatedUser, token: String) throws {
        try keychain.saveSession(user)
        try keychain.saveToken(token)
    }

    func clearAll() throws {
        try keychain.clearAll()
    }
}
