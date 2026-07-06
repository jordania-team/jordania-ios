//
//  BackendAuthServiceIntegrationTests.swift
//  JordaniaTeamIntegrationTests
//
//  Sessão 2 — Testa BackendAuthService com HTTP interceptado via MockURLProtocol.
//
//  Como funciona:
//  1. TestURLSessionFactory.make() cria uma URLSession.ephemeral com MockURLProtocol registrado.
//  2. Essa sessão é injetada em BackendAuthService(session:).
//  3. MockURLProtocol.requestHandler define a resposta determinística para cada teste.
//  4. Nenhuma chamada de rede real sai do processo.
//

import Testing
import Foundation
@testable import JordaniaTeam

@Suite("BackendAuthService Integration")
struct BackendAuthServiceIntegrationTests {

    // MARK: - Setup

    /// URL base usada nos testes — deve bater com AppConfiguration.apiBaseURL em DEBUG.
    private let baseURL = URL(string: "http://localhost:8080")!

    init() {
        // Garante que nenhum handler residual de teste anterior interfira.
        MockURLProtocol.requestHandler = nil
    }

    /// Cria BackendAuthService com URLSession mockada pronta para interceptar.
    private func makeService() -> BackendAuthService {
        BackendAuthService(session: TestURLSessionFactory.make())
    }

    // MARK: - Sucesso

    /// Caminho feliz: backend retorna 200 com payload válido.
    /// Prova: token é JWT válido (3 segmentos) e usuário é decodificado corretamente.
    @Test("login com 200 decodifica token e usuário corretamente")
    func login_success_decodesTokenAndUser() async throws {
        let loginURL = baseURL
            .appendingPathComponent("auth")
            .appendingPathComponent("login")
            .absoluteString

        MockURLProtocol.requestHandler = { _ in
            AuthFixtures.successResponse(for: loginURL)
        }

        let session = try await makeService().login(
            provider: .apple,
            identityToken: "fake-identity-token"
        )

        let tokenParts = session.accessToken.split(separator: ".")
        #expect(tokenParts.count == 3, "Token deve ser um JWT com 3 segmentos")
        #expect(!session.accessToken.isEmpty)
        #expect(session.user.id == AuthFixtures.testUserID)
        #expect(session.user.name == "Test User")
        #expect(session.refreshToken == AuthFixtures.validRefreshToken)
    }

    // MARK: - Erro 401

    /// Backend retorna 401 — deve propagar NetworkError.unauthorized.
    @Test("login com 401 lança NetworkError.unauthorized")
    func login_401_throwsUnauthorized() async throws {
        let loginURL = baseURL
            .appendingPathComponent("auth")
            .appendingPathComponent("login")
            .absoluteString

        MockURLProtocol.requestHandler = { _ in
            AuthFixtures.unauthorizedResponse(for: loginURL)
        }

        await #expect(throws: NetworkError.unauthorized) {
            try await makeService().login(
                provider: .apple,
                identityToken: "fake-identity-token"
            )
        }
    }

    // MARK: - Erro 500

    /// Backend retorna 500 — deve propagar NetworkError.serverError(statusCode: 500).
    @Test("login com 500 lança NetworkError.serverError")
    func login_500_throwsServerError() async throws {
        let loginURL = baseURL
            .appendingPathComponent("auth")
            .appendingPathComponent("login")
            .absoluteString

        MockURLProtocol.requestHandler = { _ in
            AuthFixtures.serverErrorResponse(for: loginURL)
        }

        do {
            try await makeService().login(
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

    /// Backend retorna 200 com JSON que não bate com AuthSessionResponse.
    /// Deve propagar NetworkError.decodingError.
    @Test("login com payload inválido lança NetworkError.decodingError")
    func login_invalidPayload_throwsDecodingError() async throws {
        let loginURL = baseURL
            .appendingPathComponent("auth")
            .appendingPathComponent("login")
            .absoluteString

        MockURLProtocol.requestHandler = { _ in
            AuthFixtures.invalidPayloadResponse(for: loginURL)
        }

        await #expect(throws: NetworkError.decodingError) {
            try await makeService().login(
                provider: .apple,
                identityToken: "fake-identity-token"
            )
        }
    }
}
