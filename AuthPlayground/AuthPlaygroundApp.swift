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

    init() {
        Self.configurarGoogleSignIn()
        self.sessionStore = SessionStore(persistence: SessionPersistence())
    }

    var body: some Scene {
        WindowGroup {
            AuthView()
                .environment(sessionStore)
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
            assertionFailure("GoogleSignIn-Info.plist n\u00e3o encontrado ou CLIENT_ID ausente.")
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }
}
