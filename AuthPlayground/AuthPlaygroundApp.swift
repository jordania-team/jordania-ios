//
//  AuthPlaygroundApp.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import SwiftUI
import SwiftData
import GoogleSignIn

@main
struct AuthPlaygroundApp: App {

    private let container: ModelContainer
    private let sessionStore: SessionStore

    init() {
        // Função estática para evitar uso de self antes da inicialização completa
        Self.configurarGoogleSignIn()

        let container = try! ModelContainer(for: CachedSession.self)
        self.container = container

        let persistence = SessionPersistence(modelContext: container.mainContext)
        self.sessionStore = SessionStore(persistence: persistence)
    }

    var body: some Scene {
        WindowGroup {
            AuthView()
                .environment(sessionStore)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(container)
    }

    // MARK: - Private

    private static func configurarGoogleSignIn() {
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
