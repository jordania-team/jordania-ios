//
//  GoogleAuthService.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import GoogleSignIn
import UIKit

/// Responsavel exclusivamente pelo fluxo de Sign in with Google.
/// Obtem o idToken do Google, envia ao backend e retorna AuthenticatedUser.
final class GoogleAuthService {

    // MARK: - Dependencies

    private let backendAuthService: BackendAuthService

    // MARK: - Init

    init(backendAuthService: BackendAuthService = BackendAuthService()) {
        self.backendAuthService = backendAuthService
    }

    // MARK: - Public API

    func signIn() async throws -> AuthenticatedUser {
        guard let rootViewController = await rootViewController() else {
            throw AuthError.failed("Nao foi possivel obter a view controller raiz.")
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        let googleUser = result.user

        guard let idToken = googleUser.idToken?.tokenString else {
            throw AuthError.failed("ID Token do Google nao disponivel.")
        }

        let session = try await backendAuthService.login(
            provider: .google,
            identityToken: idToken
        )

        return AuthenticatedUser(
            id: session.userId,
            name: session.name,
            email: session.email,
            provider: .google,
            accessToken: session.token
        )
    }

    func restorePreviousSignIn() async -> AuthenticatedUser? {
        guard GIDSignIn.sharedInstance.hasPreviousSignIn() else { return nil }
        do {
            let googleUser = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            guard let idToken = googleUser.idToken?.tokenString else { return nil }
            let session = try await backendAuthService.login(
                provider: .google,
                identityToken: idToken
            )
            return AuthenticatedUser(
                id: session.userId,
                name: session.name,
                email: session.email,
                provider: .google,
                accessToken: session.token
            )
        } catch {
            return nil
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    // MARK: - Helpers

    @MainActor
    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
