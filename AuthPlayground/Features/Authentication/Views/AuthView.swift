//
//  AuthView.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import AuthenticationServices
import SwiftUI

/// Tela de autenticação. Layout e apresentação apenas —
/// toda orquestração vive no AuthViewModel.
struct AuthView: View {
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(SessionStore.self) private var session
    @State private var viewModel: AuthViewModel

    init(session: SessionStore) {
        _viewModel = State(initialValue: AuthViewModel(session: session))
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // MARK: - Hero
            VStack(spacing: 16) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.indigo)

                Text("iPet")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("A rede social dos seus pets")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // MARK: - Auth Buttons
            VStack(spacing: 12) {
                if session.isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .frame(height: 50)
                } else {
                    SignInWithAppleButton(.signIn) { request in
                        viewModel.prepareAppleRequest(request)
                    } onCompletion: { result in
                        viewModel.handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 50)

                    googleSignInButton
                }

                if let error = session.authError {
                    Text(error.localizedDescription)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 52)
        }
    }

    // MARK: - Google Button

    /// Botão Google seguindo as Brand Guidelines do Google:
    /// fundo branco, logo SVG oficial, texto "Continuar com Google".
    private var googleSignInButton: some View {
        Button {
            viewModel.signInWithGoogle()
        } label: {
            Image("google-signin-button")
                .resizable()
                .scaledToFit()
                .frame(height: 50)
        }
    }
}

#Preview {
    let session = SessionStore()
    AuthView(session: session)
        .environment(session)
}
