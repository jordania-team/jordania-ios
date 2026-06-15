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
                    .font(.system(size: 72))
                    .foregroundStyle(BrandColors.primary)

                Text("iPet")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("A rede social dos seus pets")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .safeAreaInset(edge: .bottom) {
            authButtonsSection
        }
    }

    // MARK: - Auth Buttons

    private var authButtonsSection: some View {
        VStack(spacing: 12) {
            if session.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(height: BrandSpacing.buttonHeight)
            } else {
                AppleSignInButton(
                    onRequest: { viewModel.prepareAppleRequest($0) },
                    onCompletion: { viewModel.handleAppleSignIn($0) }
                )

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
        .padding(.horizontal, BrandSpacing.screenHorizontal)
        .padding(.bottom, BrandSpacing.screenBottom)
    }

    // MARK: - Google Button

    private var googleSignInButton: some View {
        Button {
            viewModel.signInWithGoogle()
        } label: {
            HStack(spacing: 10) {
                Image("google-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)

                Text("Continue with Google")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: BrandSpacing.buttonHeight)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Apple Sign In Button

/// Subview isolada: obrigatório para @Environment(\.colorScheme) reagir
/// corretamente. SignInWithAppleButton não tem estilo "automatic" —
/// preto em fundo claro, branco em fundo escuro (HIG).
private struct AppleSignInButton: View {

    @Environment(\.colorScheme) private var colorScheme

    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    var body: some View {
        SignInWithAppleButton(.signIn, onRequest: onRequest, onCompletion: onCompletion)
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(maxWidth: .infinity)
            .frame(height: BrandSpacing.buttonHeight)
    }
}

#Preview {
    let session = SessionStore()
    AuthView(session: session)
        .environment(session)
}
