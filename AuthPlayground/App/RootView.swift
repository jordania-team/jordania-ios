//
//  RootView.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 12/06/26.
//

import SwiftUI

/// Ponto de entrada da navegação.
/// Decide entre tela de login e tela de tarefas com base no estado da sessão.
struct RootView: View {

    let sessionStore: SessionStore
    let apiClient: APIClient
    let authViewModel: AuthViewModel

    var body: some View {
        if sessionStore.isSignedIn {
            TasksView(
                apiClient: apiClient,
                onSignOut: { authViewModel.signOut() }
            )
        } else {
            AuthView(session: sessionStore)
                .environment(sessionStore)
        }
    }
}
