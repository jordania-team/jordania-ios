//
//  BackendAuthServiceIntegrationTests.swift
//  JordaniaTeamIntegrationTests
//
//  Sessão 2 — Testa BackendAuthService com HTTP interceptado via MockURLProtocol.
//
//  Por que @Suite(.serialized)?
//  MockURLProtocol.requestHandler é uma `static var` compartilhada por todos os testes.
//  O Swift Testing roda testes em paralelo por padrão — sem serialização, o handler
//  de um teste vaza para o próximo, causando respostas erradas.
//  .serialized garante que cada teste roda sozinho, com seu próprio handler.
//

import Testing
import Foundation
@testable import JordaniaTeam

@Suite("BackendAuthService Integration", .serialized)
struct BackendAuthServiceIntegrationTests {

    // MARK: - Setup

    private let baseURL = URL(string: "http://localhost:8080")!

    init() {
        MockURLProtocol.requestHandler = nil
    }

    private func makeService() -> BackendAuthService {
        BackendAuthService(session: TestURLSessionFactory.make())
    }

    private var loginURL: String {
        baseURL
            .appendingPathComponent("auth")
            .appendingPathComponent("login")
            .absoluteString
    }

    // MARK: - Sucesso

    /// Caminho feliz: 200 com payload válido → token JWT + usuário corretos.
    @Test("login com 200 decodifica token e usuário corretamente")
    func login_success_decodesTokenAndUser() async throws {
        MockURLProtocol.requestHandler = { _ in
            AuthFixtures.successResponse(for: self.loginURL)
        }

        let result = try await makeService().login(
            provider: .apple,
            identityToken: "fake-identity-token"
        )

        #expect(result.accessToken.split(separator: ".").count == 3)
        #expect(!result.accessToken.isEmpty)
        #expect(result.user.id == AuthFixtures.testUserID)
        #expect(result.user.name == "Test User")
        #expect(result.refreshToken == AuthFixtures.validRefreshToken)
    }

    // MARK: - Erro 401

    /// 401 → NetworkError.unauthorized
    @Test("login com 401 lança NetworkError.unauthorized")
    func login_401_throwsUnauthorized() async throws {
        MockURLProtocol.requestHandler = { _ in
            AuthFixtures.unauthorizedResponse(for: self.loginURL)
        }

        await #expect(throws: NetworkError.unauthorized) {
            try await makeService().login(
                provider: .apple,
                identityToken: "fake-identity-token"
            )
        }
    }

    // MARK: - Erro 500

    /// 500 → NetworkError.serverError(statusCode: 500)
    @Test("login com 500 lança NetworkError.serverError")
    func login_500_throwsServerError() async throws {
        MockURLProtocol.requestHandler = { _ in
            AuthFixtures.serverErrorResponse(for: self.loginURL)
        }

        do {
            _ = try await makeService().login(
                provider: .apple,
                identityToken: "fake-identity-token"
            )
            Issue.record("Deveria ter lançado erro")
        } catch let error as NetworkError {
            if case .serverError(let code) = error {
                #expect(code == 500)
            } else {
                Issue.record("Erro esperado: serverError(500), recebido: \(error)")
            }
        }
    }

    // MARK: - Payload inválido

    /// 200 + JSON inválido → NetworkError.decodingError
    @Test("login com payload inválido lança NetworkError.decodingError")
    func login_invalidPayload_throwsDecodingError() async throws {
        MockURLProtocol.requestHandler = { _ in
            AuthFixtures.invalidPayloadResponse(for: self.loginURL)
        }

        await #expect(throws: NetworkError.decodingError) {
            try await makeService().login(
                provider: .apple,
                identityToken: "fake-identity-token"
            )
        }
    }
}
