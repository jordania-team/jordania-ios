//
//  BackendAuthService.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 01/06/26.
//

import Foundation

// TODO: Mover para variável de ambiente ou configuração de build antes de produção.
private let kBackendBaseURL = "http://localhost:8080"

/// Resposta do endpoint POST /auth/login.
/// O backend valida o identityToken do provider e retorna o JWT interno + dados do usuário.
struct AuthSessionResponse: Decodable {
    /// JWT do backend Jordania — usado em todas as chamadas autenticadas.
    let accessToken: String
    let userId: String
    let name: String?
    let email: String?

    // O backend retorna o campo como "token", mapeamos para accessToken.
    enum CodingKeys: String, CodingKey {
        case accessToken = "token"
        case userId
        case name
        case email
    }
}

/// Responsável exclusivamente pela chamada ao backend de autenticação.
/// Recebe o identityToken do provider (Apple/Google) e retorna a sessão do backend.
/// Não conhece SessionStore, View ou qualquer outro layer.
final class BackendAuthService {

    // MARK: - Public API

    /// Troca o identityToken do provider por uma sessão autenticada no backend.
    /// O backend valida a assinatura do token diretamente com Apple/Google antes de responder.
    ///
    /// - Parameters:
    ///   - provider: O provider OAuth usado (.apple ou .google)
    ///   - identityToken: O JWT emitido pelo provider (Apple: identityToken, Google: idToken)
    /// - Returns: AuthSessionResponse com accessToken e dados do usuário
    func login(provider: AuthProvider, identityToken: String) async throws -> AuthSessionResponse {
        let url = URL(string: "\(kBackendBaseURL)/auth/login")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body = LoginRequest(provider: provider.rawValue, identityToken: identityToken)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.failed("Resposta inválida do servidor.")
        }

        guard http.statusCode == 200 else {
            throw AuthError.failed("Servidor retornou status \(http.statusCode).")
        }

        return try JSONDecoder().decode(AuthSessionResponse.self, from: data)
    }
}

// MARK: - Private DTOs

private struct LoginRequest: Encodable {
    let provider: String
    let identityToken: String
}
