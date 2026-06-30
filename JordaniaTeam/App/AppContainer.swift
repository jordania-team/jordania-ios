//
//  AppContainer.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 29/06/26.
//

import Foundation
import GoogleSignIn

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
        urlSession: URLSession = .shared
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
