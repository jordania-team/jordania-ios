//
//  SessionPersistence.swift
//  JordaniaTeamA
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import Foundation

/// Responsável exclusivamente por ler e escrever sessão, access token e refresh token via Keychain.
/// A SessionStore e o TokenProvider delegam persistência para cá.
nonisolated final class SessionPersistence: Sendable {

    private let keychain: KeychainService

    init(keychain: KeychainService = KeychainService()) {
        self.keychain = keychain
    }

    // MARK: - Public API

    /// Retorna a sessão persistida se o access token ainda for válido.
    /// Token expirado remove tudo do Keychain — o usuário fará login novamente
    /// (ou o TokenProvider fará refresh proativo antes de chegar aqui).
    func loadSession() -> AuthenticatedUser? {
        guard let user = keychain.loadSession() else { return nil }
        guard let token = keychain.loadToken(), !JWT.isExpired(token) else {
            try? keychain.clearAll()
            return nil
        }
        return user
    }

    func loadAccessToken() -> String? {
        keychain.loadToken()
    }

    func loadRefreshToken() -> String? {
        keychain.loadRefreshToken()
    }

    /// Salva usuário, access token e refresh token.
    /// A persistência é sequencial; qualquer falha lança e deixa o chamador decidir.
    func save(user: AuthenticatedUser, accessToken: String, refreshToken: String) throws {
        try keychain.saveSession(user)
        try keychain.saveToken(accessToken)
        try keychain.saveRefreshToken(refreshToken)
    }

    func clearAll() throws {
        try keychain.clearAll()
    }
}
