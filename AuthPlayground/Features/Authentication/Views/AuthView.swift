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
            VStack(spacing: 12) {
                if session.isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .frame(height: BrandSpacing.buttonHeight)
                } else {
                    AppleSignInButton { request in
                        viewModel.prepareAppleRequest(request)
                    } onCompletion: { result in
                        viewModel.handleAppleSignIn(result)
                    }
                    .frame(height: BrandSpacing.buttonHeight)

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
            .background(.background)
        }
    }

    // MARK: - Google Button

    private var googleSignInButton: some View {
        Button {
            viewModel.signInWithGoogle()
        } label: {
            Image("google-signin-button")
                .resizable()
                .scaledToFit()
                .frame(height: BrandSpacing.buttonHeight)
        }
    }
}

// MARK: - Apple Sign In Button

/// Subview isolada para que @Environment(\.colorScheme) reaja
/// corretamente a mudanças de tema em tempo real.
private struct AppleSignInButton: View {

    @Environment(\.colorScheme) private var colorScheme

    let onRequest: (ASAuthorizationAppleIDRequest) -> Void
    let onCompletion: (Result<ASAuthorization, Error>) -> Void

    var body: some View {
        SignInWithAppleButton(.signIn, onRequest: onRequest, onCompletion: onCompletion)
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
    }
}

#Preview {
    let session = SessionStore()
    AuthView(session: session)
        .environment(session)
}
