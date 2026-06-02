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
    /// Continuation interna carrega apenas o identityToken — o backend resolve o userId canônico.
    private var continuation: CheckedContinuation<String, Error>?

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

        // Passo 1: obtém o identityToken da Apple via delegate.
        let identityToken = try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.performRequests()
        }

        // Passo 2: troca o identityToken pelo JWT do backend.
        let session = try await backendAuthService.login(
            provider: .apple,
            identityToken: identityToken
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

        continuation?.resume(returning: identityToken)
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
