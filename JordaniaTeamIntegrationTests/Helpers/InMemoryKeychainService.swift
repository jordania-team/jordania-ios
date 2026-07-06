//
//  InMemoryKeychainService.swift
//  JordaniaTeamIntegrationTests
//
//  Implementação em memória de KeychainServiceProtocol para uso exclusivo em testes.
//
//  Por que não usar KeychainService real nos integration tests?
//  - O Keychain real exige entitlements que podem não estar disponíveis no
//    simulador durante CI.
//  - Impede contaminação entre runs: cada instância começa limpa.
//  - Elimina estado residual no dispositivo do desenvolvedor após os testes.
//
//  Para testar SessionPersistence com isolamento total, injete esta classe:
//    let keychain = InMemoryKeychainService()
//    let persistence = SessionPersistence(keychain: keychain)
//

import Foundation
@testable import JordaniaTeam

final class InMemoryKeychainService: KeychainServiceProtocol, @unchecked Sendable {

    private var sessionData: Data?
    private var accessTokenData: Data?
    private var refreshTokenData: Data?

    // MARK: - Session

    func saveSession(_ user: AuthenticatedUser) throws {
        sessionData = try JSONEncoder().encode(user)
    }

    func loadSession() -> AuthenticatedUser? {
        guard let data = sessionData else { return nil }
        return try? JSONDecoder().decode(AuthenticatedUser.self, from: data)
    }

    // MARK: - Access Token

    func saveToken(_ token: String) throws {
        accessTokenData = token.data(using: .utf8)
    }

    func loadToken() -> String? {
        guard let data = accessTokenData else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Refresh Token

    func saveRefreshToken(_ token: String) throws {
        refreshTokenData = token.data(using: .utf8)
    }

    func loadRefreshToken() -> String? {
        guard let data = refreshTokenData else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Clear

    func clearAll() throws {
        sessionData = nil
        accessTokenData = nil
        refreshTokenData = nil
    }
}
