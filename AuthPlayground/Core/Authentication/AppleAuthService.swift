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
/// Obtém o identityToken da Apple, envia ao backend e retorna AuthenticatedUser.
/// Contrato externo mantido: signIn() -> AuthenticatedUser.
final class AppleAuthService: NSObject {

    // MARK: - Dependencies

    private let backendAuthService: BackendAuthService

    // MARK: - Private State

    private var currentNonce: String?

    /// Carrega identityToken + nome completo do credential.
    /// A Apple envia fullName apenas na primeira autorização — capturamos aqui e repassamos ao backend.
    private var continuation: CheckedContinuation<AppleCredential, Error>?

    // MARK: - Init

    init(backendAuthService: BackendAuthService = BackendAuthService()) {
        self.backendAuthService = backendAuthService
    }

    // MARK: - Public API

    func signIn() async throws -> AuthenticatedUser {
        let nonce = generateNonce()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        // Passo 1: obtém identityToken + fullName via delegate.
        // fullName só vem preenchido na primeira autorização — nas seguintes vem nil.
        let credential = try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.performRequests()
        }

        // Passo 2: troca o identityToken pelo JWT do backend.
        // Passa o nome quando disponível — o backend persiste apenas se o campo estiver presente.
        let session = try await backendAuthService.login(
            provider: .apple,
            identityToken: credential.identityToken,
            name: credential.fullName
        )

        return AuthenticatedUser(
            id: session.userId,
            name: session.name,
            email: session.email,
            provider: .apple,
            accessToken: session.accessToken
        )
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

// MARK: - ASAuthorizationControllerDelegate

extension AppleAuthService: ASAuthorizationControllerDelegate {

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let identityToken = String(data: tokenData, encoding: .utf8)
        else {
            continuation?.resume(throwing: AuthError.failed("Identity token não disponível."))
            continuation = nil
            return
        }

        // Monta o nome completo quando disponível (primeira autorização Apple).
        // Nas autorizações seguintes, fullName vem nil — o backend mantém o nome já persistido.
        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .nilIfEmpty()

        continuation?.resume(returning: AppleCredential(
            identityToken: identityToken,
            fullName: fullName
        ))
        continuation = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            continuation?.resume(throwing: AuthError.cancelled)
        } else {
            continuation?.resume(throwing: AuthError.failed(error.localizedDescription))
        }
        continuation = nil
    }
}

// MARK: - Private Types

/// Agrupa os dados relevantes do ASAuthorizationAppleIDCredential.
/// Evita passar múltiplos valores soltos pela continuation.
private struct AppleCredential {
    let identityToken: String
    let fullName: String?
}

// MARK: - String Helper

private extension String {
    /// Retorna nil se a string estiver vazia — evita persistir "" no banco.
    func nilIfEmpty() -> String? {
        isEmpty ? nil : self
    }
}
