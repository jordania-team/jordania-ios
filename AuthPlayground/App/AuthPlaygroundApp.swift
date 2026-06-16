//
//  AuthPlaygroundApp.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import SwiftUI
import GoogleSignIn

@main
struct AuthPlaygroundApp: App {

    private let sessionStore: SessionStore
    private let apiClient: APIClient

    init() {
        Self.configurarGoogleSignIn()
        let store = SessionStore(persistence: SessionPersistence())
        self.sessionStore = store
        self.apiClient = APIClient(sessionStore: store)
    }

    var body: some Scene {
        WindowGroup {
            RootView(sessionStore: sessionStore, apiClient: apiClient)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }

    // MARK: - Private

    private static func configurarGoogleSignIn() {
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
