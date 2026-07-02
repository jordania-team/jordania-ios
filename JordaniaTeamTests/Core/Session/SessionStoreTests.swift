//
//  SessionStoreTests.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 02/07/26.
//

import Foundation
import Testing

@testable import JordaniaTeam

// MARK: - StubSessionPersistence

/// Test double em memória para SessionPersistenceProtocol.
/// Permite controlar sessão inicial e simular falhas no save.
final class StubSessionPersistence: SessionPersistenceProtocol, @unchecked Sendable {

    var stubbedSession: AuthenticatedUser?
    var shouldThrowOnSave: Bool = false

    init(stubbedSession: AuthenticatedUser? = nil) {
        self.stubbedSession = stubbedSession
    }

    nonisolated func loadSession() -> AuthenticatedUser? { stubbedSession }
    nonisolated func loadAccessToken() -> String? { nil }
    nonisolated func loadRefreshToken() -> String? { nil }

    nonisolated func save(user: AuthenticatedUser, accessToken: String, refreshToken: String) throws {
        if shouldThrowOnSave { throw AuthError.failed("save failed") }
    }

    nonisolated func clearAll() throws { }
}

// MARK: - StubUserService

/// Test double para UserServiceProtocol.
/// Permite retornar um usuário de sucesso ou lançar qualquer erro.
final class StubUserService: UserServiceProtocol, @unchecked Sendable {

    enum Behavior {
        case success(AuthenticatedUser)
        case failure(Error)
    }

    var behavior: Behavior

    init(behavior: Behavior) {
        self.behavior = behavior
    }

    nonisolated func fetchCurrentUser() async throws -> AuthenticatedUser {
        switch behavior {
        case .success(let user):  return user
        case .failure(let error): throw error
        }
    }
}

// MARK: - Helpers

private func makeUser(name: String = "Gabriel Ferrari") -> AuthenticatedUser {
    AuthenticatedUser(
        id: UUID(),
        name: name,
        email: "gabriel@jordania.app",
        provider: .apple
    )
}

// MARK: - Tests

@Suite("SessionStore")
@MainActor
struct SessionStoreTests {

    // MARK: - init

    /// init com sessão salva no Keychain — estado inicial deve ser .authenticated.
    @Test func sessionStore_init_withSavedSession_stateIsAuthenticated() {
        let user  = makeUser()
        let store = SessionStore(persistence: StubSessionPersistence(stubbedSession: user))

        #expect(store.state == .authenticated)
        #expect(store.currentUser == user)
    }

    /// init sem sessão salva — estado inicial deve ser .signedOut.
    @Test func sessionStore_init_withNoSession_stateIsSignedOut() {
        let store = SessionStore(persistence: StubSessionPersistence(stubbedSession: nil))

        #expect(store.state == .signedOut)
        #expect(store.currentUser == nil)
    }

    // MARK: - signIn

    /// signIn com dados válidos — estado deve ser .authenticated e currentUser preenchido.
    @Test func sessionStore_signIn_success_stateIsAuthenticatedAndUserSet() {
        let store = SessionStore(persistence: StubSessionPersistence())
        let user  = makeUser()

        store.signIn(user: user, accessToken: "access-xyz", refreshToken: "refresh-abc")

        #expect(store.state == .authenticated)
        #expect(store.currentUser == user)
    }

    /// signIn com falha no Keychain — estado deve ser .error.
    @Test func sessionStore_signIn_keychainFailure_stateIsError() {
        let stub          = StubSessionPersistence()
        stub.shouldThrowOnSave = true
        let store         = SessionStore(persistence: stub)

        store.signIn(user: makeUser(), accessToken: "access-xyz", refreshToken: "refresh-abc")

        #expect(store.state == .error("Não foi possível salvar a sessão com segurança."))
    }

    // MARK: - signOut

    /// signOut — estado deve ser .signedOut e currentUser nil.
    @Test func sessionStore_signOut_stateIsSignedOutAndUserNil() {
        let user  = makeUser()
        let store = SessionStore(persistence: StubSessionPersistence(stubbedSession: user))

        store.signOut()

        #expect(store.state == .signedOut)
        #expect(store.currentUser == nil)
    }

    // MARK: - validateSession

    /// validateSession com sucesso — estado .authenticated e currentUser atualizado.
    @Test func sessionStore_validateSession_success_userUpdated() async {
        let user      = makeUser()
        let freshUser = makeUser(name: "Gabriel Updated")
        let store     = SessionStore(persistence: StubSessionPersistence(stubbedSession: user))

        await store.validateSession(using: StubUserService(behavior: .success(freshUser)))

        #expect(store.state == .authenticated)
        #expect(store.currentUser == freshUser)
    }

    /// validateSession com 401 — deve chamar signOut e estado ser .signedOut.
    @Test func sessionStore_validateSession_unauthorized_stateIsSignedOut() async {
        let user  = makeUser()
        let store = SessionStore(persistence: StubSessionPersistence(stubbedSession: user))

        await store.validateSession(using: StubUserService(behavior: .failure(NetworkError.unauthorized)))

        #expect(store.state == .signedOut)
        #expect(store.currentUser == nil)
    }

    /// validateSession com erro de rede — deve manter .authenticated sem deslogar.
    @Test func sessionStore_validateSession_networkError_remainsAuthenticated() async {
        let user  = makeUser()
        let store = SessionStore(persistence: StubSessionPersistence(stubbedSession: user))

        await store.validateSession(using: StubUserService(behavior: .failure(URLError(.notConnectedToInternet))))

        #expect(store.state == .authenticated)
        #expect(store.currentUser == user)
    }

    // MARK: - retry

    /// retry — deve transitar para .loading e depois .authenticated após validação com sucesso.
    @Test func sessionStore_retry_transitsToLoadingThenAuthenticated() async {
        let user      = makeUser()
        let freshUser = makeUser(name: "Gabriel Updated")
        let store     = SessionStore(persistence: StubSessionPersistence(stubbedSession: user))

        await store.retry(using: StubUserService(behavior: .success(freshUser)))

        #expect(store.state == .authenticated)
        #expect(store.currentUser == freshUser)
    }
}
