//
//  RootView.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 12/06/26.
//

import SwiftUI

/// Ponto de entrada da navegação.
/// Decide entre AuthView, PetOnboardingView ou MainTabView
/// com base no estado da sessão.
struct RootView: View {

    let container: AppContainer

    var body: some View {
        switch container.sessionStore.state {
        case .loading:
            ProgressView()
        case .authenticated:
            MainTabView(container: container)
        case .signedOut:
            AuthView(session: container.sessionStore)
                .environment(container.sessionStore)
        case .error(let message):
            SessionErrorView(message: message) {
                Task { await container.sessionStore.retry(using: container.userService) }
            }
        }
    }
}
