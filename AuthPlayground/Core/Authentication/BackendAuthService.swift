//
//  BackendAuthService.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 01/06/26.
//

import Foundation

/// Resposta do endpoint POST /auth/login.
/// O backend valida o identityToken do provider e retorna o JWT interno + dados do usuário.
struct AuthSessionResponse: Decodable {
    let token: String
    let userId: UUID
    let name: String?
    let email: String?
}

/// Responsável exclusivamente pela chamada ao backend de autenticação.
/// Recebe o identityToken do provider (Apple/Google) e retorna a sessão do backend.
/// Não conhece SessionStore, View ou qualquer outro layer.
final class BackendAuthService {

    // MARK: - Public API

    /// Troca o identityToken do provider por uma sessão autenticada no backend.
    ///
    /// - Parameters:
    ///   - provider: O provider OAuth usado (.apple ou .google)
    ///   - identityToken: O JWT emitido pelo provider (Apple: identityToken, Google: idToken)
    ///   - name: Nome do usuário — obrigatório apenas no primeiro login com Apple
    ///   - rawNonce: Nonce original (pré-SHA256) — obrigatório para Apple, nil para Google
    func login(
        provider: AuthProvider,
        identityToken: String,
        name: String? = nil,
        rawNonce: String? = nil
    ) async throws -> AuthSessionResponse {
        let url = AppConfiguration.apiBaseURL
            .appendingPathComponent("auth")
            .appendingPathComponent("login")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body = LoginRequest(
            provider: provider.rawValue,
            identityToken: identityToken,
            name: name,
            rawNonce: rawNonce
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.failed("Resposta inválida do servidor.")
        }

        guard http.statusCode == 200 else {
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
                ?? "Falha ao autenticar. Código: \(http.statusCode)."
            throw AuthError.failed(message)
        }

        return try JSONDecoder().decode(AuthSessionResponse.self, from: data)
    }
}

// MARK: - Private DTOs

private struct LoginRequest: Encodable {
    let provider: String
    let identityToken: String
    /// nil é omitido do JSON automaticamente — o backend trata ausência como string vazia.
    let name: String?
    /// Nonce original (pré-SHA256). Obrigatório para Apple Sign In.
    let rawNonce: String?
}
