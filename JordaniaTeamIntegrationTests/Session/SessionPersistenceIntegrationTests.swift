//
//  SessionPersistenceIntegrationTests.swift
//  JordaniaTeamIntegrationTests
//
//  Sessão 3 — Testa SessionPersistence com InMemoryKeychainService.
//
//  O que esses testes provam:
//  - save() persiste usuário + tokens corretamente
//  - loadSession() retorna o usuário quando o access token é válido
//  - loadSession() retorna nil e limpa o Keychain quando o token está expirado
//  - clearAll() limpa todos os dados
//

import Testing
import Foundation
@testable import JordaniaTeam

@Suite("SessionPersistence Integration")
struct SessionPersistenceIntegrationTests {

    // MARK: - Helpers

    private func makePersistence() -> (SessionPersistence, InMemoryKeychainService) {
        let keychain = InMemoryKeychainService()
        let persistence = SessionPersistence(keychain: keychain)
        return (persistence, keychain)
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

    /// Salva sessão e verifica que loadSession() retorna o mesmo usuário.
    @Test("save e loadSession retornam usuário correto com token válido")
    func save_thenLoad_returnsUser() throws {
        let (persistence, _) = makePersistence()
        let user = makeUser()

        try persistence.save(
            user: user,
            accessToken: AuthFixtures.validAccessToken,
            refreshToken: AuthFixtures.validRefreshToken
        )

        let loaded = persistence.loadSession()
        #expect(loaded?.id == user.id)
        #expect(loaded?.name == user.name)
        #expect(loaded?.email == user.email)
    }

    /// Token expirado deve fazer loadSession() retornar nil E limpar o Keychain.
    @Test("loadSession com token expirado retorna nil e limpa Keychain")
    func loadSession_expiredToken_returnsNilAndClears() throws {
        let (persistence, keychain) = makePersistence()
        let user = makeUser()

        try persistence.save(
            user: user,
            accessToken: AuthFixtures.expiredAccessToken,
            refreshToken: AuthFixtures.validRefreshToken
        )

        let loaded = persistence.loadSession()
        #expect(loaded == nil, "Token expirado deve retornar nil")
        #expect(keychain.loadToken() == nil, "Access token deve ter sido removido")
        #expect(keychain.loadSession() == nil, "Sessão deve ter sido removida")
    }

    /// clearAll() deve zerar todos os campos.
    @Test("clearAll remove sessão, access token e refresh token")
    func clearAll_removesAllData() throws {
        let (persistence, keychain) = makePersistence()
        let user = makeUser()

        try persistence.save(
            user: user,
            accessToken: AuthFixtures.validAccessToken,
            refreshToken: AuthFixtures.validRefreshToken
        )

        try persistence.clearAll()

        #expect(keychain.loadSession() == nil)
        #expect(keychain.loadToken() == nil)
        #expect(keychain.loadRefreshToken() == nil)
    }

    /// Sem dados salvos, loadSession() deve retornar nil sem erros.
    @Test("loadSession sem dados retorna nil")
    func loadSession_empty_returnsNil() {
        let (persistence, _) = makePersistence()
        #expect(persistence.loadSession() == nil)
    }
}
