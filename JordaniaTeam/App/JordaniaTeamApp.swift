//
//  JordaniaTeamApp.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import SwiftUI
import GoogleSignIn

@main
struct JordaniaTeamApp: App {

    private let sessionStore: SessionStore
    private let apiClient: APIClient
    private let authViewModel: AuthViewModel
    private let userService: UserService

    init() {
        Self.configureGoogleSignIn()

        let persistence = SessionPersistence()
        let store = SessionStore(persistence: persistence)
        let tokenProvider = TokenProvider(
            persistence: persistence,
            authService: BackendAuthService(),
            sessionStore: store
        )
        let client = APIClient(tokenProvider: tokenProvider, session: .shared, sessionStore: store)

        self.sessionStore  = store
        self.apiClient     = client
        self.authViewModel = AuthViewModel(session: store)
        self.userService   = UserService(apiClient: client)
    }

    var body: some Scene {
        WindowGroup {
            RootView(sessionStore: sessionStore, apiClient: apiClient, authViewModel: authViewModel)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .task {
                    // Validação em background: confirma que a sessão local ainda é válida no servidor.
                    // A UI já fica visível com os dados locais enquanto isso acontece.
                    await sessionStore.validateSession(using: userService)
                }
        }
    }

    // MARK: - Private

    private static func configureGoogleSignIn() {
        guard
            let path = Bundle.main.path(forResource: "GoogleSignIn-Info", ofType: "plist"),
            let plist = NSDictionary(contentsOfFile: path),
            let clientID = plist["CLIENT_ID"] as? String
        else {
            assertionFailure("GoogleSignIn-Info.plist nao encontrado ou CLIENT_ID ausente.")
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }
}
