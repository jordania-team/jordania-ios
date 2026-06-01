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

    init() {
        configurarGoogleSignIn()
    }

    var body: some Scene {
        WindowGroup {
            AuthView()
                .environment(SessionStore())
                .onOpenURL { url in
                    // Necessário para o Google capturar o redirect OAuth após autenticar no browser
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }

    // MARK: - Private

    private func configurarGoogleSignIn() {
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
