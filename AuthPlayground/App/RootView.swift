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

    var body: some View {
        if sessionStore.isSignedIn {
            TarefasView(
                sessionStore: sessionStore,
                onSignOut: { sessionStore.signOut() }
            )
        } else {
            AuthView(session: sessionStore)
                .environment(sessionStore)
        }
    }
}
