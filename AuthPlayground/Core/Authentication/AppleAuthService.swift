//
//  AppleAuthService.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import AuthenticationServices
import CryptoKit
import Foundation

/// Chave Keychain para o fullName pendente de confirmacao pelo backend.
/// A Apple entrega o nome uma unica vez — precisamos garantir que ele
/// sobreviva a falhas de rede entre o onCompletion e a resposta do backend
/// (ex: alerta de permissao de rede local ainda nao aceito na primeira execucao).
private let kPendingAppleNameKey = "jordania.apple.pendingFullName"

/// Responsavel exclusivamente pelo fluxo de Sign in with Apple.
/// Recebe o Result do onCompletion do SignInWithAppleButton,
/// persiste o fullName no Keychain antes de chamar o backend,
/// e limpa o dado apos confirmacao de sucesso.
final class AppleAuthService {

    // MARK: - Dependencies

    private let backendAuthService: BackendAuthService

    // MARK: - Init

    init(backendAuthService: BackendAuthService = BackendAuthService()) {
        self.backendAuthService = backendAuthService
    }

    // MARK: - Nonce

    private var currentNonce: String = ""

    /// Gera e armazena o nonce atual. Retorna o hash SHA-256 para o request da Apple.
    func prepareNonce() -> String {
        let nonce = generateNonce()
        currentNonce = nonce
        return sha256(nonce)
    }

    // MARK: - Public API

    /// Processa o resultado do onCompletion do SignInWithAppleButton.
    ///
    /// fullName e entregue pela Apple apenas na primeira autorizacao.
    /// Persiste no Keychain antes de chamar o backend — garante que o nome
    /// sobreviva a falhas de rede (ex: permissao de rede local ainda pendente).
    /// Apos sucesso do backend, remove o dado do Keychain.
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
                throw AuthError.failed("Identity token nao disponivel.")
            }

            // Apple entregou o nome agora (primeira autorizacao) — persiste antes de qualquer chamada de rede.
            if let receivedName = extractFullName(from: credential) {
                KeychainService.save(receivedName, forKey: kPendingAppleNameKey)
            }

            // Le do Keychain — funciona tanto na primeira tentativa quanto em retries.
            let nameToSend = KeychainService.read(forKey: kPendingAppleNameKey)

            let session = try await backendAuthService.login(
                provider: .apple,
                identityToken: identityToken,
                name: nameToSend,
                rawNonce: currentNonce.isEmpty ? nil : currentNonce
            )

            // Backend confirmou — dado temporario pode ser removido com seguranca.
            KeychainService.delete(forKey: kPendingAppleNameKey)

            return AuthenticatedUser(
                id: session.userId,
                name: session.name,
                email: session.email,
                provider: .apple,
                accessToken: session.token
            )
        }
    }

    // MARK: - Helpers

    private func extractFullName(from credential: ASAuthorizationAppleIDCredential) -> String? {
        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? nil : name
    }

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
