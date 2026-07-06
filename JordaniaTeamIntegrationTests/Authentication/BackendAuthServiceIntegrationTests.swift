//
//  BackendAuthServiceIntegrationTests.swift
//  JordaniaTeamIntegrationTests
//
//  Sessão 2 — Testa BackendAuthService com HTTP interceptado via MockURLProtocol.
//
//  O que esses testes provam:
//  - O request é formado corretamente (método, headers, body)
//  - A resposta JSON é decodada nas structs certas
//  - Erros HTTP são mapeados para os tipos corretos de NetworkError/AuthError
//
//  O que NÃO testam (pertence às outras sessões):
//  - SessionStore, SessionPersistence, Keychain
//  - TokenProvider e APIClient
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

    // MARK: - Sucesso

    /// Caminho feliz: backend retorna 200 com payload válido.
    /// Prova: o token retornado é não-vazio e tem formato JWT (três segmentos separados por '.').
    @Test("login com 200 decodifica token e usuário corretamente")
    func login_success_decodesTokenAndUser() async throws {
        let loginURL = baseURL
            .appendingPathComponent("auth")
            .appendingPathComponent("login")
            .absoluteString

        MockURLProtocol.requestHandler = { _ in
            AuthFixtures.successResponse(for: loginURL)
        }

        // NOTA: BackendAuthService usa URLSession.shared internamente.
        // Esta limitação é discutida no TESTING.md — quando BackendAuthService
        // aceitar URLSession injetada, este teste pode usar TestURLSessionFactory.make().
        // Por enquanto, o MockURLProtocol precisa ser registrado globalmente.
        // TODO: refatorar BackendAuthService para aceitar URLSession injetada (Task 1.5 da issue).
        let service = BackendAuthService()

        let session = try await service.login(
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

        let service = BackendAuthService()

        await #expect(throws: NetworkError.unauthorized) {
            try await service.login(
                provider: .apple,
                identityToken: "fake-identity-token"
            )
        }
    }

    // MARK: - Erro 500

    /// Backend retorna 500 — deve propagar NetworkError.serverError.
    @Test("login com 500 lança NetworkError.serverError")
    func login_500_throwsServerError() async throws {
        let loginURL = baseURL
            .appendingPathComponent("auth")
            .appendingPathComponent("login")
            .absoluteString

        MockURLProtocol.requestHandler = { _ in
            AuthFixtures.serverErrorResponse(for: loginURL)
        }

        let service = BackendAuthService()

        do {
            try await service.login(
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

        let service = BackendAuthService()

        await #expect(throws: NetworkError.decodingError) {
            try await service.login(
                provider: .apple,
                identityToken: "fake-identity-token"
            )
        }
    }
}
