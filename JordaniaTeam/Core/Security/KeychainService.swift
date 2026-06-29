//
//  KeychainService.swift
//  JordaniaTeamA
//
//  Created by Gabriel Ferrari on 11/06/26.
//

import Foundation
import OSLog
import Security

/// Persiste e recupera a sessão do usuário e o JWT no Keychain do iOS.
/// Dois itens distintos: sessão (identidade) e credenciais (access + refresh).
struct KeychainService {

    private let logger = Logger(subsystem: "app.jordania", category: "Keychain")
    private let service = "app.jordania.auth"

    private enum Account: String {
        case session = "current-session"
        case credentials = "session-credentials"
        case legacyAccessToken = "access-token"
    }

    // MARK: - Session (AuthenticatedUser sem token)

    func saveSession(_ user: AuthenticatedUser) throws {
        try save(Codable: user, account: .session)
    }

    func loadSession() -> AuthenticatedUser? {
        load(type: AuthenticatedUser.self, account: .session)
    }

    // MARK: - Credentials

    func saveCredentials(_ credentials: SessionCredentials) throws {
        try save(Codable: credentials, account: .credentials)
    }

    func loadCredentials() -> SessionCredentials? {
        load(type: SessionCredentials.self, account: .credentials)
    }

    func hasCredentials() -> Bool {
        loadRaw(account: .credentials) != nil
    }

    func hasLegacyAccessToken() -> Bool {
        loadRaw(account: .legacyAccessToken) != nil
    }

    // MARK: - Clear

    /// Remove sessão e token. Item inexistente não é erro.
    func clearAll() throws {
        try delete(account: .session)
        try delete(account: .credentials)
        try delete(account: .legacyAccessToken)
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
