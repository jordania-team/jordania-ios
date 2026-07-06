//
//  AppContainer.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 29/06/26.
//

import Foundation
import GoogleSignIn

// MARK: - Session Factory

/// Constrói a URLSession de produção com certificate pinning e timeouts explícitos.
///
/// Definida fora da classe porque valores default de parâmetros são avaliados
/// em contexto nonisolated — não pode ser um método `@MainActor`.
///
/// Os hashes são valores placeholder — substitua pelos SPKI SHA-256 reais
/// extraídos do servidor de produção antes do release.
/// Instruções em `CertificatePinningDelegate.swift`.
private func makeProductionSession() -> URLSession {
    let pinningDelegate = CertificatePinningDelegate(pinnedHashes: [
        // Hash ativo — substitua pelo SPKI SHA-256 real do certificado de produção
        "PLACEHOLDER_ACTIVE_SPKI_SHA256_BASE64=",
        // Hash de backup — chave futura já gerada, certificado ainda não deployado.
        // Garante rotação de certificado sem forçar novo build.
        "PLACEHOLDER_BACKUP_SPKI_SHA256_BASE64=",
    ])

    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest  = 15
    config.timeoutIntervalForResource = 60

    return URLSession(
        configuration: config,
        delegate: pinningDelegate,
        delegateQueue: nil
    )
}

// MARK: - AppContainer

/// Compõe e injeta todas as dependências da aplicação.
/// `JordaniaTeamApp` delega toda a construção e o bootstrap para cá.
@MainActor
final class AppContainer {

    let sessionStore: SessionStore
    let apiClient: APIClient
    let authViewModel: AuthViewModel
    let userService: UserService

    init(
        persistence: SessionPersistence,
        authService: BackendAuthService,
        urlSession: URLSession = makeProductionSession()
    ) {
        let store = SessionStore(persistence: persistence)
        let tokenProvider = TokenProvider(
            persistence: persistence,
            authService: authService,
            sessionStore: store
        )
        let client = APIClient(
            tokenProvider: tokenProvider,
            session: urlSession,
            sessionStore: store
        )

        self.sessionStore  = store
        self.apiClient     = client
        self.authViewModel = AuthViewModel(session: store)
        self.userService   = UserService(apiClient: client)
    }

    convenience init() {
        self.init(
            persistence: SessionPersistence(),
            authService: BackendAuthService()
        )
    }

    // MARK: - Lifecycle

    /// Configuração de SDKs de terceiros.
    /// Chamada explicitamente pelo entry point, mantendo o `init` puro.
    func bootstrap() {
        configureGoogleSignIn()
    }

    // MARK: - Private

    private func configureGoogleSignIn() {
        guard
            let path = Bundle.main.path(forResource: "GoogleSignIn-Info", ofType: "plist"),
            let plist = NSDictionary(contentsOfFile: path),
            let clientID = plist["CLIENT_ID"] as? String
        else {
            assertionFailure("GoogleSignIn-Info.plist não encontrado ou CLIENT_ID ausente.")
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }
}
