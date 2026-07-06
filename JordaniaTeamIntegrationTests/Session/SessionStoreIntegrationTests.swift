//
//  SessionStoreIntegrationTests.swift
//  JordaniaTeamIntegrationTests
//
//  Sessão 3 — Testa SessionStore com SessionPersistence real (Keychain em memória).
//
//  API real do SessionStore:
//  - signIn(user:accessToken:refreshToken:)  — síncrono, sem throws
//  - signOut()                               — síncrono
//  - state: SessionState                     — .loading | .authenticated | .signedOut | .error
//  - currentUser: AuthenticatedUser?         — separado do state
//  - Restauração de sessão acontece no init() automaticamente
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

    private func makeUser() -> AuthenticatedUser {
        AuthenticatedUser(
            id: AuthFixtures.testUserID,
            name: "Test User",
            email: "test@jordania.com",
            provider: .apple
        )
    }

    // MARK: - Testes

    /// Após signIn, o estado deve ser .authenticated e currentUser preenchido.
    @Test("signIn transiciona para .authenticated e preenche currentUser")
    func signIn_transitionsToAuthenticated() {
        let (store, _) = makeStore()
        let user = makeUser()

        store.signIn(
            user: user,
            accessToken: AuthFixtures.validAccessToken,
            refreshToken: AuthFixtures.validRefreshToken
        )

        #expect(store.state == .authenticated)
        #expect(store.currentUser?.id == AuthFixtures.testUserID)
        #expect(store.currentUser?.name == "Test User")
    }

    /// Após signIn, os tokens devem estar persistidos no Keychain (em memória).
    @Test("signIn persiste accessToken e refreshToken no Keychain")
    func signIn_persistsTokensInKeychain() {
        let (store, keychain) = makeStore()
        let user = makeUser()

        store.signIn(
            user: user,
            accessToken: AuthFixtures.validAccessToken,
            refreshToken: AuthFixtures.validRefreshToken
        )

        #expect(keychain.loadToken() == AuthFixtures.validAccessToken)
        #expect(keychain.loadRefreshToken() == AuthFixtures.validRefreshToken)
    }

    /// Com Keychain pré-populado (sessão válida), o init() do SessionStore
    /// deve restaurar automaticamente o estado para .authenticated — sem rede.
    @Test("init com Keychain válido restaura sessão para .authenticated")
    func init_validKeychain_restoresSession() throws {
        let keychain = InMemoryKeychainService()
        let persistence = SessionPersistence(keychain: keychain)

        // Pré-popula o Keychain diretamente (simula cold launch com sessão salva)
        let user = makeUser()
        try keychain.saveSession(user)
        try keychain.saveToken(AuthFixtures.validAccessToken)
        try keychain.saveRefreshToken(AuthFixtures.validRefreshToken)

        // Cria store DEPOIS de popular o Keychain — restauração ocorre no init
        let store = SessionStore(persistence: persistence)

        #expect(store.state == .authenticated)
        #expect(store.currentUser?.id == AuthFixtures.testUserID)
    }

    /// signOut() deve transicionar para .signedOut, zerar currentUser e limpar o Keychain.
    @Test("signOut transiciona para .signedOut e limpa Keychain")
    func signOut_clearsStateAndKeychain() {
        let (store, keychain) = makeStore()
        let user = makeUser()

        store.signIn(
            user: user,
            accessToken: AuthFixtures.validAccessToken,
            refreshToken: AuthFixtures.validRefreshToken
        )
        store.signOut()

        #expect(store.state == .signedOut)
        #expect(store.currentUser == nil)
        #expect(keychain.loadSession() == nil)
        #expect(keychain.loadToken() == nil)
        #expect(keychain.loadRefreshToken() == nil)
    }
}
