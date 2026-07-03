//
//  AuthViewModel.swift
//  JordaniaTeamA
//
//  Created by Gabriel Ferrari on 12/06/26.
//

import AuthenticationServices
import Foundation
import Observation

// MARK: - Protocols (enable test-double injection per TESTING.md)

/// Interface mínima de AppleAuthService exigida pelo AuthViewModel.
@MainActor
protocol AppleAuthServicing: AnyObject {
    func prepareNonce() -> String
    func handle(_ result: Result<ASAuthorization, Error>) async throws -> AuthSession
}

/// Interface mínima de GoogleAuthServicing exigida pelo AuthViewModel.
@MainActor
protocol GoogleAuthServicing: AnyObject {
    func signIn() async throws -> AuthSession
    func signOut()
}

// MARK: - Conformances

extension AppleAuthService: AppleAuthServicing {}
extension GoogleAuthService: GoogleAuthServicing {}

// MARK: - ViewModel

/// Orquestra o fluxo de autenticação: services de provider + atualização da SessionStore.
/// A View só dispara ações e reflete estado — nunca toca os services diretamente.
@Observable
@MainActor
final class AuthViewModel {

    // MARK: - State
    var isLoading: Bool = false
    var errorMessage: String? = nil
    private var signInTask: Task<Void, Never>?

    // MARK: - Dependencies
    private let session: SessionStore
    private let appleAuthService: any AppleAuthServicing
    private let googleAuthService: any GoogleAuthServicing

    // MARK: - Init

    init(
        session: SessionStore,
        appleAuthService: (any AppleAuthServicing)? = nil,
        googleAuthService: (any GoogleAuthServicing)? = nil
    ) {
        self.session = session
        self.appleAuthService = appleAuthService ?? AppleAuthService()
        self.googleAuthService = googleAuthService ?? GoogleAuthService()
    }

    // MARK: - Apple

    /// Chamado no onRequest do SignInWithAppleButton — gera o nonce obrigatório.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        request.nonce = appleAuthService.prepareNonce()
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        performSignIn { [appleAuthService] in
            try await appleAuthService.handle(result)
        }
    }

    // MARK: - Google

    func signInWithGoogle() {
        performSignIn { [googleAuthService] in
            try await googleAuthService.signIn()
        }
    }

    // MARK: - Sign Out

    func signOut() {
        if session.currentUser?.provider == .google {
            googleAuthService.signOut()
        }
        session.signOut()
    }

    // MARK: - Private

    /// Fluxo único para qualquer provider: loading → service → sessão.
    /// Cancelamentos (usuário ou Task) são silenciosos; o resto vira mensagem na UI.
    private func performSignIn(_ operation: @escaping () async throws -> AuthSession) {
        guard signInTask == nil else { return }
        isLoading = true
        signInTask = Task {
            defer {
                isLoading = false
                signInTask = nil
            }
            do {
                let authSession = try await operation()
                session.signIn(
                    user: authSession.user,
                    accessToken: authSession.accessToken,
                    refreshToken: authSession.refreshToken
                )
            } catch AuthError.cancelled, NetworkError.cancelled {
                // silencioso
            } catch let networkError as NetworkError {
                errorMessage = networkError.errorDescription ?? "Não foi possível concluir o login. Tente novamente."
            } catch {
                errorMessage = "Não foi possível concluir o login. Tente novamente."
            }
        }
    }
}
