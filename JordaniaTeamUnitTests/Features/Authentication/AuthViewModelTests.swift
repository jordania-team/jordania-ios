//
//  AuthViewModelTests.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 03/07/26.
//

import Foundation
import Testing

@testable import JordaniaTeam

// MARK: - Mock: GoogleAuthServicing

/// Mock de GoogleAuthServicing para uso exclusivo em testes.
/// Modo síncrono: configure `stubbedResult` para retorno imediato.
/// Modo bloqueante: `stubbedResult = nil` suspende até `resume()` ser chamado
/// — permite observar `isLoading == true` de forma determinística sem Task.sleep.
@MainActor
final class MockGoogleAuthService: GoogleAuthServicing {

    private(set) var signInCallCount = 0
    private(set) var signOutCallCount = 0

    var stubbedResult: Result<AuthSession, Error>?
    private var pendingContinuation: CheckedContinuation<AuthSession, Error>?

    func signIn() async throws -> AuthSession {
        signInCallCount += 1
        if let stubbedResult {
            return try stubbedResult.get()
        }
        return try await withCheckedThrowingContinuation { continuation in
            pendingContinuation = continuation
        }
    }

    func signOut() {
        signOutCallCount += 1
    }

    /// Libera a continuation pendente com um resultado.
    func resume(with result: Result<AuthSession, Error>) {
        pendingContinuation?.resume(with: result)
        pendingContinuation = nil
    }
}

// MARK: - Helpers

/// Retorna uma AuthSession stub válida.
/// Função livre (não extension em tupla) — tuple extensions são experimentais em Swift 6.
@MainActor
private func stubSession() -> AuthSession {
    (
        user: AuthenticatedUser(
            id: UUID(),
            name: "Gabriel Ferrari",
            email: "gabriel@jordania.app",
            provider: .google
        ),
        accessToken: "stub-access",
        refreshToken: "stub-refresh"
    )
}

/// SessionStore em memória usando StubSessionPersistence existente em SessionStoreTests.
@MainActor
private func makeStore() -> SessionStore {
    SessionStore(persistence: StubSessionPersistence())
}

// MARK: - Tests

@Suite("AuthViewModel")
@MainActor
struct AuthViewModelTests {

    // MARK: - isLoading lifecycle

    /// performSignIn: isLoading vai para true durante a execução e false ao terminar.
    @Test func authViewModel_performSignIn_isLoadingTogglesAroundExecution() async {
        let google = MockGoogleAuthService()
        google.stubbedResult = nil // modo bloqueante — task fica suspensa no mock
        let viewModel = AuthViewModel(session: makeStore(), googleAuthService: google)

        #expect(viewModel.isLoading == false)

        viewModel.signInWithGoogle()

        // Cede ao executor para a Task interna rodar e setar isLoading = true
        await Task.yield()

        #expect(viewModel.isLoading == true)

        google.resume(with: .success(stubSession()))

        // Drena até isLoading virar false (robusto contra variações do scheduler)
        for _ in 0..<10 {
            await Task.yield()
            if !viewModel.isLoading { break }
        }

        #expect(viewModel.isLoading == false)
    }

    // MARK: - Success

    /// performSignIn com sucesso: nenhum errorMessage.
    @Test func authViewModel_performSignIn_success_noErrorMessage() async {
        let google = MockGoogleAuthService()
        google.stubbedResult = .success(stubSession())
        let viewModel = AuthViewModel(session: makeStore(), googleAuthService: google)

        viewModel.signInWithGoogle()
        await Task.yield()
        await Task.yield()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }

    // MARK: - AuthError.cancelled

    /// performSignIn com AuthError.cancelled: silencioso — sem errorMessage.
    @Test func authViewModel_performSignIn_authCancelled_silentNoErrorMessage() async {
        let google = MockGoogleAuthService()
        google.stubbedResult = .failure(AuthError.cancelled)
        let viewModel = AuthViewModel(session: makeStore(), googleAuthService: google)

        viewModel.signInWithGoogle()
        await Task.yield()
        await Task.yield()

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }

    // MARK: - NetworkError

    /// performSignIn com NetworkError: errorMessage preenchido com a descrição do erro.
    @Test func authViewModel_performSignIn_networkError_errorMessagePopulated() async {
        let google = MockGoogleAuthService()
        google.stubbedResult = .failure(NetworkError.noConnection)
        let viewModel = AuthViewModel(session: makeStore(), googleAuthService: google)

        viewModel.signInWithGoogle()
        await Task.yield()
        await Task.yield()

        #expect(viewModel.errorMessage == NetworkError.noConnection.errorDescription)
        #expect(viewModel.isLoading == false)
    }

    // MARK: - Duplicate tap

    /// Tap duplo durante loading: segunda chamada ignorada — signIn só é chamado uma vez.
    @Test func authViewModel_performSignIn_ignoresDuplicateTap() async {
        let google = MockGoogleAuthService()
        google.stubbedResult = nil // bloqueia para garantir que a task ainda está ativa
        let viewModel = AuthViewModel(session: makeStore(), googleAuthService: google)

        viewModel.signInWithGoogle()

        // Cede ao executor para a Task interna rodar e chamar signIn() no mock
        await Task.yield()

        #expect(viewModel.isLoading == true)
        #expect(google.signInCallCount == 1)

        // Segundo tap — deve ser ignorado pelo guard signInTask == nil
        viewModel.signInWithGoogle()

        #expect(google.signInCallCount == 1)

        // Limpa: libera a continuation para não vazar Tasks pendentes
        google.resume(with: .success(stubSession()))
        await Task.yield()
        await Task.yield()
    }
}
