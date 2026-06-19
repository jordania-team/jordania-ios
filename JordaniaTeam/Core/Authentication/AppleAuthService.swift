//
//  AppleAuthService.swift
//  JordaniaTeamA
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import AuthenticationServices
import CryptoKit
import Foundation

/// Nome pendente de confirmacao pelo backend, vinculado ao usuario Apple que o originou.
/// A Apple entrega o fullName uma unica vez — ele precisa sobreviver a falhas de rede
/// entre o onCompletion e a resposta do backend (ex: alerta de permissao de rede local
/// ainda nao aceito na primeira execucao). Vinculado ao credential.user para nunca
/// enviar o nome de um usuario na conta de outro. Nao e dado sensivel — UserDefaults
/// e suficiente para esta finalidade temporaria.
private struct PendingAppleName: Codable {
    let userID: String
    let name: String

    static let storageKey = "jordania.apple.pendingFullName"

    static func load(for userID: String) -> String? {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let pending = try? JSONDecoder().decode(PendingAppleName.self, from: data),
            pending.userID == userID
        else { return nil }
        return pending.name
    }

    static func save(_ name: String, for userID: String) {
        let pending = PendingAppleName(userID: userID, name: name)
        guard let data = try? JSONEncoder().encode(pending) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}

/// Responsavel exclusivamente pelo fluxo de Sign in with Apple.
/// @MainActor: o fluxo nasce na UI e a classe tem estado mutavel (currentNonce).
@MainActor
final class AppleAuthService {

    private let backendAuthService: BackendAuthService

    private var currentNonce: String?

    init(backendAuthService: BackendAuthService = BackendAuthService()) {
        self.backendAuthService = backendAuthService
    }

    // MARK: - Public API

    /// Gera e armazena o nonce atual. Retorna o hash SHA-256 para o request da Apple.
    /// Deve ser chamado no onRequest do SignInWithAppleButton, antes de cada tentativa.
    func prepareNonce() -> String {
        let nonce = generateNonce()
        currentNonce = nonce
        return sha256(nonce)
    }

    /// Processa o resultado do onCompletion do SignInWithAppleButton.
    func handle(_ result: Result<ASAuthorization, Error>) async throws -> AuthSession {
        // Nonce e one-time: consome e limpa, em sucesso ou falha.
        defer { currentNonce = nil }

        switch result {
        case .failure(let error):
            throw mapAuthorizationError(error)

        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let identityToken = String(data: tokenData, encoding: .utf8)
            else {
                throw AuthError.failed("Não foi possível concluir o login com a Apple.")
            }

            // Nonce ausente = prepareNonce() nao foi chamado no onRequest (wiring da View).
            guard let rawNonce = currentNonce else {
                throw AuthError.failed("Fluxo de autenticação inválido. Tente novamente.")
            }

            if let receivedName = extractFullName(from: credential) {
                PendingAppleName.save(receivedName, for: credential.user)
            }

            let session = try await backendAuthService.login(
                provider: .apple,
                identityToken: identityToken,
                name: PendingAppleName.load(for: credential.user),
                rawNonce: rawNonce
            )

            PendingAppleName.clear()

            return session
        }
    }

    // MARK: - Helpers

    /// Mapeia erros do AuthenticationServices para erros de dominio.
    /// Nunca expoe localizedDescription do sistema na UI.
    private func mapAuthorizationError(_ error: Error) -> AuthError {
        guard let authError = error as? ASAuthorizationError else {
            return .failed("Não foi possível concluir o login com a Apple.")
        }
        switch authError.code {
        case .canceled:
            return .cancelled
        case .notInteractive, .notHandled:
            return .failed("O login com a Apple não está disponível no momento.")
        default:
            return .failed("Não foi possível concluir o login com a Apple. Tente novamente.")
        }
    }

    private func extractFullName(from credential: ASAuthorizationAppleIDCredential) -> String? {
        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return name.isEmpty ? nil : name
    }

    /// SystemRandomNumberGenerator e criptograficamente seguro em plataformas Apple —
    /// nao trocar por SecRandomCopyBytes manual.
    private func generateNonce(length: Int = 32) -> String {
        let charset = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._"
        return String((0..<length).map { _ in charset.randomElement()! })
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
