//
//  SessionStoreIntegrationTests.swift
//  JordaniaTeamIntegrationTests
//
//  Sessão 3 — Testa SessionStore com SessionPersistence real (Keychain em memória).
//
//  O que esses testes provam:
//  - signIn() com AuthSession válida → estado .authenticated + dados persistidos
//  - Restauração de sessão: Keychain pré-populado → .authenticated sem rede
//  - signOut() → estado .signedOut + Keychain limpo
//
//  Limitação atual: SessionStore.signIn() recebe um AuthSession e persiste via
//  SessionPersistence. Esses testes verificam essa colaboração diretamente,
//  sem passar pelo BackendAuthService (que é coberto pelos BackendAuthServiceIntegrationTests).
//

import Testing
import Foundation
@testable import JordaniaTeam

@Suite("SessionStore Integration")
@MainActor
struct SessionStoreIntegrationTests {

    // MARK: - Helpers

    private func makeStore() -> (SessionStore, InMemoryKeychainService) {
        let keychain = InMemoryKeychainService()
        let persistence = SessionPersistence(keychain: keychain)
        let store = SessionStore(persistence: persistence)
        return (store, keychain)
    }

    private func makeAuthSession() -> AuthSession {
        let user = AuthenticatedUser(
            id: AuthFixtures.testUserID,
            name: "Test User",
            email: "test@jordania.com",
            provider: .apple
        )
        return (user: user, accessToken: AuthFixtures.validAccessToken, refreshToken: AuthFixtures.validRefreshToken)
    }

    // MARK: - Testes

    /// Após signIn com AuthSession válida, o estado deve ser .authenticated.
    @Test("signIn com AuthSession válida transiciona para .authenticated")
    func signIn_validSession_transitionsToAuthenticated() async throws {
        let (store, _) = makeStore()
        let authSession = makeAuthSession()

        try await store.signIn(with: authSession)

        guard case .authenticated(let user) = store.sessionState else {
            Issue.record("Estado esperado: .authenticated, recebido: \(store.sessionState)")
            return
        }
        #expect(user.id == AuthFixtures.testUserID)
    }

    /// Após signIn, os tokens devem estar persistidos no Keychain (em memória).
    @Test("signIn persiste accessToken e refreshToken no Keychain")
    func signIn_persistsTokensInKeychain() async throws {
        let (store, keychain) = makeStore()
        let authSession = makeAuthSession()

        try await store.signIn(with: authSession)

        #expect(keychain.loadToken() == AuthFixtures.validAccessToken)
        #expect(keychain.loadRefreshToken() == AuthFixtures.validRefreshToken)
    }

    /// Com Keychain pré-populado (sessão válida), restoreSession() deve
    /// resultar em .authenticated sem fazer nenhuma chamada de rede.
    @Test("restoreSession com sessão válida no Keychain resulta em .authenticated")
    func restoreSession_validKeychain_authenticates() async throws {
        let keychain = InMemoryKeychainService()
        let persistence = SessionPersistence(keychain: keychain)

        // Pré-popula o Keychain diretamente (simula lançamento com sessão salva)
        let user = AuthenticatedUser(
            id: AuthFixtures.testUserID,
            name: "Test User",
            email: "test@jordania.com",
            provider: .apple
        )
        try keychain.saveSession(user)
        try keychain.saveToken(AuthFixtures.validAccessToken)
        try keychain.saveRefreshToken(AuthFixtures.validRefreshToken)

        // Cria store DEPOIS de popular o Keychain — simula cold launch
        let store = SessionStore(persistence: persistence)
        await store.restoreSession()

        guard case .authenticated(let restoredUser) = store.sessionState else {
            Issue.record("Estado esperado: .authenticated, recebido: \(store.sessionState)")
            return
        }
        #expect(restoredUser.id == AuthFixtures.testUserID)
    }

    /// signOut() deve transicionar para .signedOut e limpar o Keychain.
    @Test("signOut transiciona para .signedOut e limpa Keychain")
    func signOut_clearsStateAndKeychain() async throws {
        let (store, keychain) = makeStore()
        let authSession = makeAuthSession()

        try await store.signIn(with: authSession)
        await store.signOut()

        guard case .signedOut = store.sessionState else {
            Issue.record("Estado esperado: .signedOut, recebido: \(store.sessionState)")
            return
        }
        #expect(keychain.loadSession() == nil)
        #expect(keychain.loadToken() == nil)
        #expect(keychain.loadRefreshToken() == nil)
    }
}
