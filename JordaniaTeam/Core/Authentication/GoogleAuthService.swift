//
//  GoogleAuthService.swift
//  JordaniaTeamA
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import GoogleSignIn
import OSLog
import UIKit

/// Responsavel exclusivamente pelo fluxo de Sign in with Google.
/// Obtem o idToken do Google, envia ao backend e retorna AuthSession.
///
/// Importa UIKit por exigencia do GoogleSignIn SDK (apresentacao via UIViewController) —
/// excecao unica a regra de "no UIKit in Core/", registrada no Decision Log.
///
/// Restauracao de sessao NAO acontece aqui: o JWT no Keychain e a unica fonte de
/// verdade (via SessionStore/SessionPersistence). Identity tokens so existem no login.
@MainActor
final class GoogleAuthService {

    private static let logger = Logger(subsystem: "app.jordania", category: "GoogleAuth")

    private let backendAuthService: BackendAuthService

    init(backendAuthService: BackendAuthService = BackendAuthService()) {
        self.backendAuthService = backendAuthService
    }

    // MARK: - Public API

    func signIn() async throws -> AuthSession {
        guard let rootViewController = rootViewController() else {
            Self.logger.error("Root view controller indisponível para apresentar o Google Sign In.")
            throw AuthError.failed("Não foi possível iniciar o login com o Google.")
        }

        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        } catch let error as GIDSignInError where error.code == .canceled {
            throw AuthError.cancelled
        } catch {
            Self.logger.error("Google Sign In falhou: \(error)")
            throw AuthError.failed("Não foi possível concluir o login com o Google. Tente novamente.")
        }

        guard let idToken = result.user.idToken?.tokenString else {
            Self.logger.error("Google Sign In concluiu sem idToken.")
            throw AuthError.failed("Não foi possível concluir o login com o Google. Tente novamente.")
        }

        return try await backendAuthService.login(
            provider: .google,
            identityToken: idToken
        )
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }

    // MARK: - Helpers

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow?
            .rootViewController
    }
}
