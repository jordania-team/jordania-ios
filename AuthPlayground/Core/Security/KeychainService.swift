//
//  KeychainService.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 11/06/26.
//

import Foundation
import Security

/// Responsável por persistir e recuperar a sessão do usuário no Keychain do iOS.
/// O Keychain é o único lugar seguro para armazenar JWTs — nunca SwiftData ou UserDefaults.
final class KeychainService {

    // MARK: - Constants

    private let service = "app.jordania.auth"
    private let account = "current-session"

    // MARK: - Public API

    /// Persiste a sessão no Keychain.
    /// Remove qualquer entrada anterior antes de salvar (upsert seguro).
    func save(_ user: AuthenticatedUser) throws {
        let data = try JSONEncoder().encode(user)

        // Remove entrada anterior antes de adicionar — evita errSecDuplicateItem
        deleteEntry()

        let attributes: [String: Any] = [
            kSecClass as String:          kSecClassGenericPassword,
            kSecAttrService as String:    service,
            kSecAttrAccount as String:    account,
            kSecValueData as String:      data,
            // Acessível após primeiro desbloqueio, apenas neste dispositivo.
            // Correto para tokens de sessão — não migra via iCloud Keychain.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw AuthError.failed("Não foi possível salvar a sessão com segurança. (\(status))")
        }
    }

    /// Recupera a sessão persistida, se existir.
    func load() -> AuthenticatedUser? {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String:  true,
            kSecMatchLimit as String:  kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return try? JSONDecoder().decode(AuthenticatedUser.self, from: data)
    }

    /// Remove a sessão do Keychain.
    func clear() {
        deleteEntry()
    }

    // MARK: - Private

    private func deleteEntry() {
        let query: [String: Any] = [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
