//
//  AuthViewModelTests.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 03/07/26.
//

import Foundation
import Testing

@testable import JordaniaTeam

// MARK: - Mock: AppleAuthServicing

/// Mock de AppleAuthServicing para uso exclusivo em testes.
/// Nunca lança por padrão; configure `stubbedResult` para simular
/// sucesso, cancelamento ou erros de rede.
@MainActor
final class MockAppleAuthService: AppleAuthServicing {

    /// Número de vezes que `handle` foi chamado.
    private(set) var handleCallCount = 0

    /// Resultado a retornar. Se `nil`, bloqueia até que `resume()` seja
    /// chamado — permite observar `isLoading == true` de forma determinística.
    var stubbedResult: Result<AuthSession, Error>? = .success(AuthSession.stub)

    /// Continuation usada quando `stubbedResult == nil`.
    private var pendingContinuation: CheckedContinuation<AuthSession, Error>?

    func prepareNonce() -> String { "stub-nonce" }

    func handle(_ result: Result<ASAuthorization, Error>) async throws -> AuthSession {
        handleCallCount += 1
        if let stubbedResult {
            return try stubbedResult.get()
        }
        // Modo bloqueante: suspende até resume() ser chamado pelo teste.
        return try await withCheckedThrowingContinuation { continuation in
            pendingContinuation = continuation
        }
    }

    /// Libera a continuation pendente com um resultado.
    func resume(with result: Result<AuthSession, Error>) {
        pendingContinuation?.resume(with: result)
        pendingContinuation = nil
    }
}

// MARK: - Mock: GoogleAuthServicing

/// Mock de GoogleAuthServicing para uso exclusivo em testes.
@MainActor
final class MockGoogleAuthService: GoogleAuthServicing {

    private(set) var signInCallCount = 0
    private(set) var signOutCallCount = 0

    var stubbedResult: Result<AuthSession, Error>? = .success(AuthSession.stub)
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

    func resume(with result: Result<AuthSession, Error>) {
        pendingContinuation?.resume(with: result)
        pendingContinuation = nil
    }
}

// MARK: - Helpers

private extension AuthSession {
    static let stub: AuthSession = (
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
        google.stubbedResult = nil // modo bloqueante — a task fica suspensa
        let viewModel = AuthViewModel(session: makeStore(), googleAuthService: google)

        // Antes de qualquer chamada: deve ser false
        #expect(viewModel.isLoading == false)

        // Dispara sem await — a task fica suspensa no mock
        viewModel.signInWithGoogle()

        // Neste ponto a Task foi criada mas ainda não terminou → deve ser true
        #expect(viewModel.isLoading == true)

        // Libera o mock com sucesso e aguarda a task concluir
        google.resume(with: .success(AuthSession.stub))
        await Task.yield() // cede ao executor para a task da VM terminar
        await Task.yield()

        #expect(viewModel.isLoading == false)
    }

    // MARK: - Success

    /// performSignIn com sucesso: nenhum errorMessage.
    @Test func authViewModel_performSignIn_success_noErrorMessage() async {
        let google = MockGoogleAuthService()
        google.stubbedResult = .success(AuthSession.stub)
        let viewModel = AuthViewModel(session: makeStore(), googleAuthService: google)

        viewModel.signInWithGoogle()
        // Aguarda a task completar (mock síncrono via stubbedResult)
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

        // Primeiro tap — task criada, mock suspenso
        viewModel.signInWithGoogle()
        #expect(viewModel.isLoading == true)

        // Segundo tap enquanto loading — deve ser ignorado pelo guard
        viewModel.signInWithGoogle()

        // Apenas uma chamada deve ter chegado ao service
        #expect(google.signInCallCount == 1)

        // Limpa: libera a continuation para não vazar
        google.resume(with: .success(AuthSession.stub))
        await Task.yield()
        await Task.yield()
    }
}
