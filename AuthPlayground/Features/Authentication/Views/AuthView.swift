//
//  AuthView.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import AuthenticationServices
import SwiftUI

/// Tela principal de autenticação. Layout e apresentação apenas —
/// toda orquestração vive no AuthViewModel.
struct AuthView: View {

    @Environment(SessionStore.self) private var session
    @State private var viewModel: AuthViewModel

    init(session: SessionStore) {
        _viewModel = State(initialValue: AuthViewModel(session: session))
    }

    var body: some View {
        NavigationStack {
            Group {
                if session.isSignedIn {
                    signedInView
                } else {
                    signedOutView
                }
            }
            .animation(.easeInOut, value: session.isSignedIn)
            .navigationTitle("Auth Playground")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Signed Out

    private var signedOutView: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "person.badge.key.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.indigo)

                Text("Bem-vindo")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Escolha um método para entrar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 16) {
                if session.isLoading {
                    ProgressView()
                        .controlSize(.large)
                } else {
                    SignInWithAppleButton(.signIn) { request in
                        viewModel.prepareAppleRequest(request)
                    } onCompletion: { result in
                        viewModel.handleAppleSignIn(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)

                    Button {
                        viewModel.signInWithGoogle()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "globe")
                                .font(.system(size: 18, weight: .medium))
                            Text("Entrar com Google")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.regularMaterial)
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                        }
                    }
                }

                if let error = session.authError {
                    Text(error.localizedDescription)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Signed In

    private var signedInView: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                Text("Autenticado")
                    .font(.title2)
                    .fontWeight(.semibold)

                if let name = session.currentUser?.name {
                    Text(name)
                        .font(.headline)
                }

                if let email = session.currentUser?.email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let provider = session.currentUser?.provider {
                    Text("Provider: \(provider.displayName)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }

                #if DEBUG
                // Validação visual da spike — impossível compilar em Release.
                if let token = session.currentUser?.accessToken {
                    Text("JWT: \(String(token.prefix(24)))…")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospaced()
                        .padding(.top, 2)
                }
                #endif
            }

            Spacer()

            Button(role: .destructive) {
                viewModel.signOut()
            } label: {
                Text("Sair")
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    let session = SessionStore()
    AuthView(session: session)
        .environment(session)
}
