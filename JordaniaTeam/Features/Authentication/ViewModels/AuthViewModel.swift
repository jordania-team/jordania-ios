//
//  AuthViewModel.swift
//  JordaniaTeamA
//
//  Created by Gabriel Ferrari on 12/06/26.
//

import AuthenticationServices
import Foundation
import Observation

/// Orquestra o fluxo de autenticação: services de provider + atualização da SessionStore.
/// A View só dispara ações e reflete estado — nunca toca os services diretamente.
@Observable
@MainActor
final class AuthViewModel {

    // MARK: - Dependencies

    private var signInTask: Task<Void, Never>?
    private let session: SessionStore
    private let appleAuthService: AppleAuthService
    private let googleAuthService: GoogleAuthService
    private let backendAuthService: BackendAuthService

    // MARK: - Init

    init(
        session: SessionStore,
        appleAuthService: AppleAuthService? = nil,
        googleAuthService: GoogleAuthService? = nil,
        backendAuthService: BackendAuthService = BackendAuthService()
    ) {
        self.session = session
        self.appleAuthService = appleAuthService ?? AppleAuthService()
        self.googleAuthService = googleAuthService ?? GoogleAuthService()
        self.backendAuthService = backendAuthService
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
        let provider = session.currentUser?.provider
        let accessToken = session.loadCredentials()?.accessToken

        Task { @MainActor in
            if provider == .google {
                googleAuthService.signOut()
            }

            if let accessToken {
                session.setLogoutStatus("POST /auth/logout iniciado")
                do {
                    let result = try await backendAuthService.logout(accessToken: accessToken)
                    session.setLogoutStatus("POST /auth/logout -> HTTP \(result.statusCode)")
                } catch {
                    session.setLogoutStatus("POST /auth/logout falhou: \(String(describing: error))")
                }
            } else {
                session.setLogoutStatus("POST /auth/logout ignorado: access token ausente")
            }

            session.signOut()
        }
    }

    // MARK: - Private

    /// Fluxo único para qualquer provider: loading → service → sessão.
    /// Cancelamentos (usuário ou Task) são silenciosos; o resto vira mensagem na UI.
    private func performSignIn(_ operation: @escaping () async throws -> AuthSession) {
        guard signInTask == nil else { return }
        session.isLoading = true
        signInTask = Task {
            defer { signInTask = nil }
            do {
                let authSession = try await operation()
                session.signIn(user: authSession.user, credentials: authSession.credentials)
            } catch AuthError.cancelled, NetworkError.cancelled {
                session.isLoading = false
            } catch let networkError as NetworkError {
                let message = networkError.errorDescription ?? "Não foi possível concluir o login. Tente novamente."
                session.setError(.failed(message))
            } catch {
                session.setError(.failed("Não foi possível concluir o login. Tente novamente."))
            }
        }
    }
}
