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
    @State private var googleAuthService = GoogleAuthService()

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
                    // Botão nativo Apple — HIG compliant.
                    // onRequest: gera o nonce via prepareNonce() e configura os scopes.
                    // onCompletion: repassa o Result diretamente ao AppleAuthService.
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = appleAuthService.prepareNonce()
                    } onCompletion: { result in
                        signInWithApple(result: result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)

                    // Google
                    Button {
                        signInWithGoogle()
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

                Text("Provider: \(session.currentUser?.provider == .apple ? "Apple" : "Google")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)

                // DEBUG: exibe o accessToken truncado para validar a spike.
                // TODO: Remover antes de produção.
                if let token = session.currentUser?.accessToken {
                    let preview = String(token.prefix(24)) + "…"
                    Text("JWT: \(preview)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospaced()
                        .padding(.top, 2)
                }
            }

            Spacer()

            Button(role: .destructive) {
                signOut()
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

    private func signInWithApple(result: Result<ASAuthorization, Error>) {
        session.isLoading = true
        Task {
            do {
                let user = try await appleAuthService.handle(result)
                session.signIn(with: user)
            } catch AuthError.cancelled {
                session.isLoading = false
            } catch {
                session.setError(.failed(error.localizedDescription))
            }
        }
    }

    private func signInWithGoogle() {
        session.isLoading = true
        Task {
            do {
                let user = try await googleAuthService.signIn()
                session.signIn(with: user)
            } catch AuthError.cancelled {
                session.isLoading = false
            } catch {
                session.setError(.failed(error.localizedDescription))
            }
        }
    }

    private func signOut() {
        if session.currentUser?.provider == .google {
            googleAuthService.signOut()
        }
        session.signOut()
    }
}

#Preview {
    AuthView()
        .environment(SessionStore())
}
