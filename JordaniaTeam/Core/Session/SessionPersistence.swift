//
//  SessionPersistence.swift
//  JordaniaTeamA
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import Foundation

/// Responsável exclusivamente por ler e escrever sessão e credenciais via Keychain.
/// A SessionStore delega persistência para cá, sem conhecer Security framework diretamente.
final class SessionPersistence {

    private let keychain: KeychainService

    init(keychain: KeychainService = KeychainService()) {
        self.keychain = keychain
    }

    // MARK: - Public API

    /// Retorna a sessão persistida se houver refresh token válido.
    /// Access token expirado não derruba a sessão; o APIClient tenta refresh.
    func loadSession() -> AuthenticatedUser? {
        guard let user = keychain.loadSession() else {
            try? keychain.clearAll()
            return nil
        }
        guard let credentials = keychain.loadCredentials(), !credentials.isRefreshExpired else {
            try? keychain.clearAll()
            return nil
        }
        return user
    }

    func save(user: AuthenticatedUser, credentials: SessionCredentials) throws {
        try keychain.saveSession(user)
        try keychain.saveCredentials(credentials)
    }

    func save(credentials: SessionCredentials) throws {
        try keychain.saveCredentials(credentials)
    }

    func clearAll() throws {
        try keychain.clearAll()
    }

    func hasCredentials() -> Bool {
        keychain.hasCredentials()
    }

    func loadCredentials() -> SessionCredentials? {
        keychain.loadCredentials()
    }

    func debugSnapshot(user: AuthenticatedUser?) -> SessionDebugSnapshot {
        let credentials = keychain.loadCredentials()
        return SessionDebugSnapshot(
            hasSession: user != nil,
            hasCredentials: credentials != nil,
            hasLegacyAccessToken: keychain.hasLegacyAccessToken(),
            accessTokenMasked: credentials?.maskedAccessToken,
            refreshTokenMasked: credentials?.maskedRefreshToken,
            accessExpiresAt: credentials?.accessExpiresAt,
            refreshExpiresAt: credentials?.refreshExpiresAt,
            accessClaims: credentials?.accessClaims
        )
    }
}
