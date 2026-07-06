//
//  SessionPersistenceTests.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 01/07/26.
//

import Foundation
import Testing

@testable import JordaniaTeam

// MARK: - InMemoryKeychainService

/// Test double em memória para KeychainService.
/// Evita entitlements de Keychain no sandbox de testes unitários.
final class InMemoryKeychainService: KeychainServiceProtocol, @unchecked Sendable {

    private var sessionData: Data?
    private var accessToken: String?
    private var refreshToken: String?

    nonisolated func saveSession(_ user: AuthenticatedUser) throws {
        sessionData = try JSONEncoder().encode(user)
    }

    nonisolated func loadSession() -> AuthenticatedUser? {
        guard let data = sessionData else { return nil }
        return try? JSONDecoder().decode(AuthenticatedUser.self, from: data)
    }

    nonisolated func saveToken(_ token: String) throws {
        accessToken = token
    }

    nonisolated func loadToken() -> String? {
        accessToken
    }

    nonisolated func saveRefreshToken(_ token: String) throws {
        refreshToken = token
    }

    nonisolated func loadRefreshToken() -> String? {
        refreshToken
    }

    nonisolated func clearAll() throws {
        sessionData  = nil
        accessToken  = nil
        refreshToken = nil
    }
}

// MARK: - Helpers

private func makeToken(exp: TimeInterval) -> String {
    let header  = #"{"alg":"HS256","typ":"JWT"}"#
    let payload = #"{"exp":\#(Int(exp))}"#

    func encode(_ string: String) -> String {
        Data(string.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    return "\(encode(header)).\(encode(payload)).fakesignature"
}

private func makeUser() -> AuthenticatedUser {
    AuthenticatedUser(
        id: UUID(),
        name: "Gabriel Ferrari",
        email: "gabriel@jordania.app",
        provider: .apple
    )
}

// MARK: - Tests

@Suite("SessionPersistence")
struct SessionPersistenceTests {

    // MARK: - loadSession

    /// Sessão salva com access token válido — deve retornar o usuário.
    @Test func sessionPersistence_loadSession_validToken_returnsUser() throws {
        let keychain    = InMemoryKeychainService()
        let persistence = SessionPersistence(keychain: keychain)
        let user        = makeUser()

        try persistence.save(user: user, accessToken: makeToken(exp: Date().timeIntervalSince1970 + 3600), refreshToken: "refresh-abc")

        #expect(persistence.loadSession() == user)
    }

    /// Access token expirado — deve retornar nil e limpar o Keychain.
    @Test func sessionPersistence_loadSession_expiredToken_returnsNilAndClears() throws {
        let keychain    = InMemoryKeychainService()
        let persistence = SessionPersistence(keychain: keychain)

        try persistence.save(user: makeUser(), accessToken: makeToken(exp: Date().timeIntervalSince1970 - 60), refreshToken: "refresh-abc")

        #expect(persistence.loadSession() == nil)
        #expect(keychain.loadSession() == nil)
        #expect(keychain.loadToken() == nil)
        #expect(keychain.loadRefreshToken() == nil)
    }

    /// Nenhuma sessão salva — deve retornar nil sem erro.
    @Test func sessionPersistence_loadSession_noSession_returnsNil() {
        let persistence = SessionPersistence(keychain: InMemoryKeychainService())
        #expect(persistence.loadSession() == nil)
    }

    // MARK: - save

    /// save persiste usuário, access token e refresh token corretamente.
    @Test func sessionPersistence_save_persistsAllFields() throws {
        let keychain    = InMemoryKeychainService()
        let persistence = SessionPersistence(keychain: keychain)
        let user        = makeUser()

        try persistence.save(user: user, accessToken: "access-xyz", refreshToken: "refresh-abc")

        #expect(keychain.loadSession() == user)
        #expect(keychain.loadToken() == "access-xyz")
        #expect(keychain.loadRefreshToken() == "refresh-abc")
    }

    // MARK: - clearAll

    /// clearAll remove todos os dados do Keychain.
    @Test func sessionPersistence_clearAll_removesAllData() throws {
        let keychain    = InMemoryKeychainService()
        let persistence = SessionPersistence(keychain: keychain)

        try persistence.save(user: makeUser(), accessToken: "access-xyz", refreshToken: "refresh-abc")
        try persistence.clearAll()

        #expect(keychain.loadSession() == nil)
        #expect(keychain.loadToken() == nil)
        #expect(keychain.loadRefreshToken() == nil)
    }

    // MARK: - loadAccessToken / loadRefreshToken

    /// loadAccessToken retorna o token correto após save.
    @Test func sessionPersistence_loadAccessToken_returnsCorrectToken() throws {
        let keychain    = InMemoryKeychainService()
        let persistence = SessionPersistence(keychain: keychain)

        try persistence.save(user: makeUser(), accessToken: "access-xyz", refreshToken: "refresh-abc")

        #expect(persistence.loadAccessToken() == "access-xyz")
    }

    /// loadRefreshToken retorna o token correto após save.
    @Test func sessionPersistence_loadRefreshToken_returnsCorrectToken() throws {
        let keychain    = InMemoryKeychainService()
        let persistence = SessionPersistence(keychain: keychain)

        try persistence.save(user: makeUser(), accessToken: "access-xyz", refreshToken: "refresh-abc")

        #expect(persistence.loadRefreshToken() == "refresh-abc")
    }
}
