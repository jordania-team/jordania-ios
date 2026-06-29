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

    private let container = AppContainer()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .task {
                    container.bootstrap()
                    await container.sessionStore.validateSession(using: container.userService)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await container.sessionStore.validateSession(using: container.userService) }
        }
    }
}
