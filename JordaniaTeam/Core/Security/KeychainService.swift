//
//  KeychainService.swift
//  JordaniaTeamA
//
//  Created by Gabriel Ferrari on 11/06/26.
//

import Foundation
import OSLog
import Security

/// Persiste e recupera a sessão do usuário, o access JWT e o refresh token no Keychain do iOS.
nonisolated struct KeychainService: Sendable {

    private let logger = Logger(subsystem: "app.jordania", category: "Keychain")
    private let service = "app.jordania.auth"

    private enum Account: String {
        case session      = "current-session"
        case accessToken  = "access-token"
        case refreshToken = "refresh-token"
    }

    // MARK: - Session (AuthenticatedUser sem token)

    func saveSession(_ user: AuthenticatedUser) throws {
        try save(Codable: user, account: .session)
    }

    func loadSession() -> AuthenticatedUser? {
        load(type: AuthenticatedUser.self, account: .session)
    }

    // MARK: - Access Token

    func saveToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw AuthError.failed("Token inválido.")
        }
        try saveRaw(data: data, account: .accessToken)
    }

    func loadToken() -> String? {
        guard let data = loadRaw(account: .accessToken) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Refresh Token

    func saveRefreshToken(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw AuthError.failed("Refresh token inválido.")
        }
        try saveRaw(data: data, account: .refreshToken)
    }

    func loadRefreshToken() -> String? {
        guard let data = loadRaw(account: .refreshToken) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Clear

    /// Remove sessão, access token e refresh token. Item inexistente não é erro.
    func clearAll() throws {
        try delete(account: .session)
        try delete(account: .accessToken)
        try delete(account: .refreshToken)
    }

    // MARK: - Private primitives

    private func save<T: Encodable>(Codable value: T, account: Account) throws {
        let data = try JSONEncoder().encode(value)
        try saveRaw(data: data, account: account)
    }

    private func load<T: Decodable>(type: T.Type, account: Account) -> T? {
        guard let data = loadRaw(account: account) else { return nil }
        guard let value = try? JSONDecoder().decode(T.self, from: data) else {
            logger.error("Item no Keychain corrompido ou schema antigo (\(account.rawValue)) — removendo.")
            try? delete(account: account)
            return nil
        }
        return value
    }

    private func saveRaw(data: Data, account: Account) throws {
        let query = baseQuery(account: account)
        let update: [String: Any] = [kSecValueData as String: data]

        var status = SecItemUpdate(query as CFDictionary, update as CFDictionary)

        if status == errSecItemNotFound {
            var attributes = query
            attributes[kSecValueData as String] = data
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(attributes as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            logger.error("Falha ao salvar (\(account.rawValue)): \(Self.describe(status))")
            throw AuthError.failed("Não foi possível salvar a sessão com segurança.")
        }
    }

    private func loadRaw(account: Account) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecItemNotFound {
                logger.error("Falha ao ler (\(account.rawValue)): \(Self.describe(status))")
            }
            return nil
        }
        return data
    }

    private func delete(account: Account) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            logger.error("Falha ao remover (\(account.rawValue)): \(Self.describe(status))")
            throw AuthError.failed("Não foi possível encerrar a sessão com segurança.")
        }
    }

    private func baseQuery(account: Account) -> [String: Any] {
        [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account.rawValue
        ]
    }

    private static func describe(_ status: OSStatus) -> String {
        (SecCopyErrorMessageString(status, nil) as String?) ?? "OSStatus \(status)"
    }
}
