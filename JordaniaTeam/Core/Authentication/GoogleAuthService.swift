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
///
/// # PKCE (RFC 7636)
/// O fluxo OAuth 2.0 do Google exige PKCE para prevenir ataques de interceptação
/// do authorization code (code interception attack). O GoogleSignIn SDK gerencia
/// isso de forma transparente e automática:
///
/// 1. Gera um `code_verifier` criptográfico aleatório (≥ 256 bits de entropia).
/// 2. Deriva o `code_challenge` via SHA-256: `BASE64URL(SHA256(code_verifier))`.
/// 3. Envia `code_challenge` + `code_challenge_method=S256` no authorization request.
/// 4. Envia o `code_verifier` original na troca do authorization code por tokens.
/// 5. O servidor Google valida que SHA256(code_verifier) == code_challenge antes de emitir tokens.
///
/// Nenhum código manual de PKCE é necessário nem possível nesta camada —
/// o SDK não expõe o code_verifier e não permite sobrescrevê-lo.
/// Para detalhes, ver: https://developers.google.com/identity/protocols/oauth2/native-app
@MainActor
final class GoogleAuthService {

    private static let logger = Logger(subsystem: "app.jordania", category: "GoogleAuth")

    private let backendAuthService: BackendAuthService

    init(backendAuthService: BackendAuthService = BackendAuthService()) {
        self.backendAuthService = backendAuthService
    }

    // MARK: - Public API

    /// Inicia o fluxo de Sign in with Google.
    ///
    /// O SDK gerencia internamente PKCE (code_verifier + code_challenge SHA-256),
    /// o state parameter e a troca segura do authorization code por tokens.
    /// O único valor que atravessa para o backend é o `idToken` — o JWT de identidade
    /// emitido pelo Google após a autenticação bem-sucedida.
    func signIn() async throws -> AuthSession {
        guard let rootViewController = rootViewController() else {
            Self.logger.error("Root view controller indisponível para apresentar o Google Sign In.")
            throw AuthError.failed("Não foi possível iniciar o login com o Google.")
        }

        let result: GIDSignInResult
        do {
            // GIDSignIn.signIn(withPresenting:) orquestra internamente:
            // - Geração do code_verifier e code_challenge (PKCE/RFC 7636)
            // - Geração do state parameter (CSRF)
            // - Abertura do authorization URL via ASWebAuthenticationSession
            // - Troca do authorization code por access token + id token
            // - Validação do state retornado pelo servidor
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

        // Apenas o idToken é enviado ao backend Jordania.
        // O code_verifier, code_challenge e state nunca saem do SDK.
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
