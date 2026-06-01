//
//  GoogleAuthService.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import GoogleSignIn
import UIKit

/// Responsável exclusivamente pelo fluxo de Sign in with Google.
/// Segue o mesmo contrato do AppleAuthService: retorna AuthenticatedUser ou lança AuthError.
final class GoogleAuthService {

    // MARK: - Public API

    /// Inicia o fluxo de Sign in with Google.
    /// Requer a rootViewController ativa para apresentar o fluxo OAuth.
    func signIn() async throws -> AuthenticatedUser {
        guard let rootViewController = await rootViewController() else {
            throw AuthError.failed("Não foi possível obter a view controller raiz.")
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        let user = result.user

        guard let userID = user.userID else {
            throw AuthError.failed("ID do usuário não disponível.")
        }

        return AuthenticatedUser(
            id: userID,
            name: user.profile?.name,
            email: user.profile?.email,
            provider: .google
        )
    }

    /// Restaura a sessão anterior do Google, se existir.
    /// Deve ser chamado no app launch para evitar login desnecessário.
    func restorePreviousSignIn() async -> AuthenticatedUser? {
        guard GIDSignIn.sharedInstance.hasPreviousSignIn() else { return nil }

        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            guard let userID = user.userID else { return nil }
            return AuthenticatedUser(
                id: userID,
                name: user.profile?.name,
                email: user.profile?.email,
                provider: .google
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
