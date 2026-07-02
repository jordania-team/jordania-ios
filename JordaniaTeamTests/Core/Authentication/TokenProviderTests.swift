//
//  TokenProviderTests.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 02/07/26.
//

import Foundation
import Testing

@testable import JordaniaTeam

// MARK: - JWT helpers

/// Gera um JWT mínimo com `exp` calculado a partir de agora + offset em segundos.
/// Não é assinado — apenas estrutura válida para os testes de parsing.
private func makeJWT(expiresInSeconds offset: TimeInterval) -> String {
    let exp = Int(Date().timeIntervalSince1970) + Int(offset)
    let payload = #"{"exp":\#(exp)}"#
    let encoded = Data(payload.utf8).base64EncodedString()
        .replacingOccurrences(of: "=", with: "")
    return "header.\(encoded).signature"
}

// MARK: - StubBackendAuthService

final class StubBackendAuthService: BackendAuthServiceProtocol, @unchecked Sendable {

    enum Behavior {
        case success(accessToken: String, refreshToken: String)
        case failure(Error)
    }

    var behavior: Behavior
    private(set) var refreshCallCount: Int = 0

    init(behavior: Behavior) {
        self.behavior = behavior
    }

    func refresh(refreshToken: String) async throws -> AuthSession {
        refreshCallCount += 1
        switch behavior {
        case .success(let access, let refresh):
            let user = AuthenticatedUser(
                id: UUID(),
                name: "Gabriel Ferrari",
                email: "gabriel@jordania.app",
                provider: .apple
            )
            return (user: user, accessToken: access, refreshToken: refresh)
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - Helpers

/// Monta um StubSessionPersistence com tokens opcionais pré-carregados.
private func makePersistence(
    accessToken: String? = nil,
    refreshToken: String? = "valid-refresh-token"
) -> StubSessionPersistence {
    let stub = StubSessionPersistence()
    stub.stubbedAccessToken  = accessToken
    stub.stubbedRefreshToken = refreshToken
    return stub
}

/// StubSessionPersistence precisa expor access/refresh token para os testes de TokenProvider.
/// Extendemos o stub existente com propriedades opcionais.
extension StubSessionPersistence {
    var stubbedAccessToken:  String? {
        get { _stubbedAccessToken }
        set { _stubbedAccessToken = newValue }
    }
    var stubbedRefreshToken: String? {
        get { _stubbedRefreshToken }
        set { _stubbedRefreshToken = newValue }
    }
}

// MARK: - Tests

@Suite("TokenProvider")
@MainActor
struct TokenProviderTests {

    // MARK: - validAccessToken

    /// Token com > 10 min de vida → retorna sem chamar refresh.
    @Test func tokenProvider_validAccessToken_tokenFresh_returnsWithoutRefresh() async throws {
        let freshToken  = makeJWT(expiresInSeconds: 3600)    // 1h de vida
        let persistence = makePersistence(accessToken: freshToken)
        let authService = StubBackendAuthService(behavior: .success(accessToken: "new", refreshToken: "new-refresh"))
        let store       = SessionStore(persistence: persistence)
        let provider    = TokenProvider(persistence: persistence, authService: authService, sessionStore: store)

        let token = try await provider.validAccessToken()

        #expect(token == freshToken)
        #expect(authService.refreshCallCount == 0)
    }

    /// Token com < 10 min de vida → dispara refresh proativo.
    @Test func tokenProvider_validAccessToken_tokenNearExpiry_triggersRefresh() async throws {
        let nearlyExpiredToken = makeJWT(expiresInSeconds: 300)  // 5 min — dentro do skew de 10 min
        let persistence = makePersistence(accessToken: nearlyExpiredToken)
        let authService = StubBackendAuthService(behavior: .success(accessToken: "new-access", refreshToken: "new-refresh"))
        let store       = SessionStore(persistence: persistence)
        let provider    = TokenProvider(persistence: persistence, authService: authService, sessionStore: store)

        let token = try await provider.validAccessToken()

        #expect(token == "new-access")
        #expect(authService.refreshCallCount == 1)
    }

    // MARK: - forceRefresh

    /// forceRefresh com sucesso → retorna novo access token.
    @Test func tokenProvider_forceRefresh_success_returnsNewToken() async throws {
        let persistence = makePersistence()
        let authService = StubBackendAuthService(behavior: .success(accessToken: "new-access", refreshToken: "new-refresh"))
        let store       = SessionStore(persistence: persistence)
        let provider    = TokenProvider(persistence: persistence, authService: authService, sessionStore: store)

        let token = try await provider.forceRefresh()

        #expect(token == "new-access")
        #expect(authService.refreshCallCount == 1)
    }

    /// forceRefresh com 401 → lança NetworkError.unauthorized e chama signOut.
    @Test func tokenProvider_forceRefresh_sessionExpired_throwsAndSignsOut() async throws {
        let user        = AuthenticatedUser(id: UUID(), name: "Gabriel", email: nil, provider: .apple)
        let persistence = makePersistence()
        let authService = StubBackendAuthService(behavior: .failure(AuthError.sessionExpired))
        let store       = SessionStore(persistence: StubSessionPersistence(stubbedSession: user))
        let provider    = TokenProvider(persistence: persistence, authService: authService, sessionStore: store)

        await #expect(throws: NetworkError.unauthorized) {
            try await provider.forceRefresh()
        }
        #expect(store.state == .signedOut)
    }

    // MARK: - Coalescing

    /// Duas chamadas simultâneas a forceRefresh → backend chamado exatamente 1 vez.
    @Test func tokenProvider_forceRefresh_concurrent_coalescedToSingleCall() async throws {
        let persistence = makePersistence()
        let authService = StubBackendAuthService(behavior: .success(accessToken: "coalescido", refreshToken: "r"))
        let store       = SessionStore(persistence: persistence)
        let provider    = TokenProvider(persistence: persistence, authService: authService, sessionStore: store)

        async let t1 = provider.forceRefresh()
        async let t2 = provider.forceRefresh()

        let (r1, r2) = try await (t1, t2)

        #expect(r1 == "coalescido")
        #expect(r2 == "coalescido")
        #expect(authService.refreshCallCount == 1)
    }

    /// forceRefresh durante refresh em andamento → segunda chamada espera e recebe mesmo resultado.
    @Test func tokenProvider_forceRefresh_duringInflightRefresh_waitsSameResult() async throws {
        let persistence = makePersistence()
        let authService = StubBackendAuthService(behavior: .success(accessToken: "in-flight", refreshToken: "r"))
        let store       = SessionStore(persistence: persistence)
        let provider    = TokenProvider(persistence: persistence, authService: authService, sessionStore: store)

        // Dispara primeiro refresh
        async let first = provider.forceRefresh()
        // Dispara segundo imediatamente (ainda dentro do mesmo refresh em voo)
        async let second = provider.forceRefresh()

        let (r1, r2) = try await (first, second)

        #expect(r1 == r2)
        #expect(authService.refreshCallCount == 1)
    }
}
