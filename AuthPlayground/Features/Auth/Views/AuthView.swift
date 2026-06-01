//
//  AuthView.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import SwiftUI
import AuthenticationServices

/// Tela principal de autenticação.
/// Responsável apenas por refletir o estado da SessionStore e disparar ações.
/// Nenhuma lógica de negócio aqui.
struct AuthView: View {

    @Environment(SessionStore.self) private var session
    @State private var appleAuthService = AppleAuthService()

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
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { _ in
                        // O fluxo real é coordenado pelo AppleAuthService via Task abaixo.
                        // Este callback não é usado quando usamos async/await diretamente.
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .onTapGesture {
                        signInWithApple()
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

                Text("Provider: \(session.currentUser?.provider == .apple ? "Apple" : "Google")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }

            Spacer()

            Button(role: .destructive) {
                session.signOut()
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

    // MARK: - Actions

    private func signInWithApple() {
        session.isLoading = true
        Task {
            do {
                let user = try await appleAuthService.signIn()
                session.signIn(with: user)
            } catch AuthError.cancelled {
                session.isLoading = false
            } catch {
                session.setError(.failed(error.localizedDescription))
            }
        }
    }
}

#Preview {
    AuthView()
        .environment(SessionStore())
}
