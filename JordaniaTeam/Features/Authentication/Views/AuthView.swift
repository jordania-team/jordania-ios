//
//  AuthView.swift
//  JordaniaTeamA
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

                Text("The social network for your pets")
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
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(height: BrandSpacing.buttonHeight * 2 + 12)
            } else {
                AppleSignInButton(
                    onRequest: { viewModel.prepareAppleRequest($0) },
                    onCompletion: { viewModel.handleAppleSignIn($0) }
                )

                GoogleSignInButton {
                    viewModel.signInWithGoogle()
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, BrandSpacing.screenHorizontal)
        .padding(.bottom, BrandSpacing.screenBottom)
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
        SignInWithAppleButton(.continue, onRequest: onRequest, onCompletion: onCompletion)
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(maxWidth: .infinity)
            .frame(height: BrandSpacing.buttonHeight)
            .environment(\.locale, Locale(identifier: "en")) // mantem o título em ingles mesmo em devices com outro idioma
            // SignInWithAppleButton (wrapper de ASAuthorizationAppleIDButton) lê o
            // colorScheme só na criação e não re-renderiza no toggle de tema.
            // recriar via .id força o redraw; o botão é stateless, sem um custo real.
            .id(colorScheme)
    }
}

// MARK: - Google Sign In Button

/// Subview isolada pelo mesmo motivo do AppleSignInButton:
/// @Environment(\.colorScheme) só reage corretamente na view que o lê.
/// Visual espelha o botão da Apple: fundo preto no light, branco no dark (HIG).
private struct GoogleSignInButton: View {

    @Environment(\.colorScheme) private var colorScheme

    let action: () -> Void

    private var backgroundColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var foregroundColor: Color {
        colorScheme == .dark ? .black : .white
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image("google-logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)

                Text("Continue with Google")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(foregroundColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: BrandSpacing.buttonHeight)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: BrandSpacing.buttonCornerRadius))
        }
        .buttonStyle(.plain)
        // garante leitura correta no VoiceOver, independente do nome do asset.
        .accessibilityLabel("Continue with Google")
    }
}

#Preview {
    let session = SessionStore()
    AuthView(session: session)
        .environment(session)
}
