//
//  SessionPersistenceProtocol.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 02/07/26.
//

/// Abstração de persistência de sessão.
/// Permite substituição por test doubles sem entitlements de Keychain.
nonisolated protocol SessionPersistenceProtocol: Sendable {
    func loadSession() -> AuthenticatedUser?
    func loadAccessToken() -> String?
    func loadRefreshToken() -> String?
    func save(user: AuthenticatedUser, accessToken: String, refreshToken: String) throws
    func clearAll() throws
}

extension SessionPersistence: SessionPersistenceProtocol {}
