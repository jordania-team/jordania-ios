//
//  AppleAuthService.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import AuthenticationServices
import CryptoKit
import Foundation

/// Responsável exclusivamente pelo fluxo de Sign in with Apple.
/// Recebe o Result do onCompletion do SignInWithAppleButton,
/// envia o identityToken ao backend e retorna AuthenticatedUser.
final class AppleAuthService {

    // MARK: - Dependencies

    private let backendAuthService: BackendAuthService

    // MARK: - Init

    init(backendAuthService: BackendAuthService = BackendAuthService()) {
        self.backendAuthService = backendAuthService
    }

    // MARK: - Nonce

    /// Gera e armazena o nonce atual. Deve ser chamado ao configurar o request.
    private(set) var currentNonce: String = ""

    func prepareNonce() -> String {
        let nonce = generateNonce()
        currentNonce = nonce
        return sha256(nonce)
    }

    // MARK: - Public API

    /// Processa o resultado do onCompletion do SignInWithAppleButton.
    /// A Apple entrega fullName apenas na primeira autorização — capturado aqui.
    func handle(_ result: Result<ASAuthorization, Error>) async throws -> AuthenticatedUser {
        switch result {
        case .failure(let error):
            if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                throw AuthError.cancelled
            }
            throw AuthError.failed(error.localizedDescription)

        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let identityToken = String(data: tokenData, encoding: .utf8)
            else {
                throw AuthError.failed("Identity token não disponível.")
            }

            // fullName só vem preenchido na primeira autorização.
            // Nas seguintes vem nil — o backend mantém o nome já persistido.
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
                .nilIfEmpty()

            let session = try await backendAuthService.login(
                provider: .apple,
                identityToken: identityToken,
                name: fullName
            )

            return AuthenticatedUser(
                id: session.userId,
                name: session.name,
                email: session.email,
                provider: .apple,
                accessToken: session.accessToken
            )
        }
    }

    // MARK: - Nonce Helpers

    private func generateNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(Security.kSecRandomDefault, randoms.count, &randoms)
            guard status == errSecSuccess else { continue }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - String Helper

private extension String {
    /// Retorna nil se a string estiver vazia — evita persistir "" no banco.
    func nilIfEmpty() -> String? {
        isEmpty ? nil : self
    }
}
