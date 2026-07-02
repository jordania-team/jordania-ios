//
//  APIClientTests.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 02/07/26.
//

import Foundation
import Testing

@testable import JordaniaTeam

// MARK: - Helpers

/// URLSession configurada para usar MockURLProtocol.
private func makeMockSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

/// Resposta HTTP simples.
private func makeResponse(status: Int, url: URL) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
}

private let testURL = URL(string: "https://api.jordania.app/test")!

/// Monta um TokenProvider real com stubs de persistence e authService.
/// O token de acesso configurado em `accessToken` controla se há refresh proativo ou não.
private func makeTokenProvider(
    accessToken: String,
    refreshToken: String = "valid-refresh",
    authBehavior: StubBackendAuthService.Behavior = .success(accessToken: "refreshed-token", refreshToken: "new-refresh"),
    sessionStore: SessionStore
) -> TokenProvider {
    let persistence = StubSessionPersistence()
    persistence.stubbedAccessToken  = accessToken
    persistence.stubbedRefreshToken = refreshToken
    let authService = StubBackendAuthService(behavior: authBehavior)
    return TokenProvider(persistence: persistence, authService: authService, sessionStore: sessionStore)
}

/// JWT com vida longa — não dispara refresh proativo.
private func freshToken() -> String {
    makeJWT(expiresInSeconds: 3600)
}

// MARK: - Tests

@Suite("APIClient", .serialized)
@MainActor
struct APIClientTests {

    // MARK: - 200 simples

    /// Request com token válido → 200 → retorna Data corretamente.
    @Test func apiClient_perform_success_returnsData() async throws {
        let expectedData = Data("response body".utf8)
        let store        = SessionStore(persistence: StubSessionPersistence())
        let provider     = makeTokenProvider(accessToken: freshToken(), sessionStore: store)
        let session      = makeMockSession()
        let client       = APIClient(tokenProvider: provider, session: session, sessionStore: store)

        MockURLProtocol.requestHandler = { _ in
            (makeResponse(status: 200, url: testURL), expectedData)
        }

        let data = try await client.perform(URLRequest(url: testURL))

        #expect(data == expectedData)
    }

    // MARK: - 401 → refresh → retry → 200

    /// 401 na primeira tentativa → refresh → retry retorna 200 com nova data.
    @Test func apiClient_perform_401thenRefreshSuccess_returnsData() async throws {
        let expectedData = Data("retried body".utf8)
        let store        = SessionStore(persistence: StubSessionPersistence())
        let provider     = makeTokenProvider(accessToken: freshToken(), sessionStore: store)
        let session      = makeMockSession()
        let client       = APIClient(tokenProvider: provider, session: session, sessionStore: store)

        var callCount = 0
        MockURLProtocol.requestHandler = { _ in
            callCount += 1
            if callCount == 1 {
                return (makeResponse(status: 401, url: testURL), Data())
            }
            return (makeResponse(status: 200, url: testURL), expectedData)
        }

        let data = try await client.perform(URLRequest(url: testURL))

        #expect(data == expectedData)
        #expect(callCount == 2)
    }

    // MARK: - 401 → refresh → retry → 401 → signOut

    /// 401 persiste após refresh → chama signOut + lança .unauthorized.
    @Test func apiClient_perform_401afterRefresh_signOutAndThrows() async throws {
        let user         = AuthenticatedUser(id: UUID(), name: "Gabriel", email: nil, provider: .apple)
        let persistence  = StubSessionPersistence(stubbedSession: user)
        let store        = SessionStore(persistence: persistence)
        let provider     = makeTokenProvider(accessToken: freshToken(), sessionStore: store)
        let session      = makeMockSession()
        let client       = APIClient(tokenProvider: provider, session: session, sessionStore: store)

        MockURLProtocol.requestHandler = { _ in
            (makeResponse(status: 401, url: testURL), Data())
        }

        await #expect(throws: NetworkError.unauthorized) {
            try await client.perform(URLRequest(url: testURL))
        }
        #expect(store.state == .signedOut)
    }

    // MARK: - Erro de rede

    /// Erro de rede (.notConnectedToInternet) → lança NetworkError.noConnection.
    @Test func apiClient_perform_networkError_throwsCorrectError() async throws {
        let store    = SessionStore(persistence: StubSessionPersistence())
        let provider = makeTokenProvider(accessToken: freshToken(), sessionStore: store)
        let session  = makeMockSession()
        let client   = APIClient(tokenProvider: provider, session: session, sessionStore: store)

        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        await #expect(throws: NetworkError.noConnection) {
            try await client.perform(URLRequest(url: testURL))
        }
    }

    // MARK: - Authorization header

    /// Todo request deve carregar Authorization: Bearer <token> no header.
    @Test func apiClient_perform_alwaysSendsBearerToken() async throws {
        let token    = freshToken()
        let store    = SessionStore(persistence: StubSessionPersistence())
        let provider = makeTokenProvider(accessToken: token, sessionStore: store)
        let session  = makeMockSession()
        let client   = APIClient(tokenProvider: provider, session: session, sessionStore: store)

        var capturedRequest: URLRequest?
        MockURLProtocol.requestHandler = { request in
            capturedRequest = request
            return (makeResponse(status: 200, url: testURL), Data())
        }

        _ = try await client.perform(URLRequest(url: testURL))

        let authHeader = capturedRequest?.value(forHTTPHeaderField: "Authorization")
        #expect(authHeader == "Bearer \(token)")
    }
}
