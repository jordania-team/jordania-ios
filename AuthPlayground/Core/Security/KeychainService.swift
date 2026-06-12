//
//  KeychainService.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 11/06/26.
//

import Foundation
import OSLog
import Security

/// Persiste e recupera a sessão do usuário no Keychain do iOS.
/// O Keychain é o único lugar seguro para armazenar JWTs — nunca SwiftData ou UserDefaults.
final class KeychainService {

    private static let logger = Logger(subsystem: "app.jordania", category: "Keychain")

    private let service = "app.jordania.auth"
    private let account = "current-session"

    // MARK: - Public API

    /// Persiste a sessão no Keychain.
    /// Upsert via SecItemUpdate + SecItemAdd fallback — atômico, sem a janela de
    /// perda de sessão do padrão delete+add (ver Decision Log).
    func save(_ user: AuthenticatedUser) throws {
        let data = try JSONEncoder().encode(user)

        let query = baseQuery()
        let update: [String: Any] = [kSecValueData as String: data]

        var status = SecItemUpdate(query as CFDictionary, update as CFDictionary)

        if status == errSecItemNotFound {
            var attributes = query
            attributes[kSecValueData as String] = data
            // Acessível após primeiro desbloqueio, apenas neste dispositivo —
            // não migra via iCloud Keychain nem backups.
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(attributes as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            Self.logger.error("Falha ao salvar sessão: \(Self.describe(status))")
            throw AuthError.failed("Não foi possível salvar a sessão com segurança.")
        }
    }

    /// Recupera a sessão persistida, se existir.
    /// Entrada corrompida ou com schema antigo é removida — nunca fica órfã no Keychain.
    func load() -> AuthenticatedUser? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecItemNotFound {
                Self.logger.error("Falha ao ler sessão: \(Self.describe(status))")
            }
            return nil
        }

        guard let user = try? JSONDecoder().decode(AuthenticatedUser.self, from: data) else {
            Self.logger.error("Sessão no Keychain corrompida ou com schema antigo — removendo.")
            try? clear()
            return nil
        }
        return user
    }

    /// Remove a sessão do Keychain. Item inexistente não é erro.
    func clear() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            Self.logger.error("Falha ao remover sessão: \(Self.describe(status))")
            throw AuthError.failed("Não foi possível encerrar a sessão com segurança.")
        }
    }

    // MARK: - Private

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String:       kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static func describe(_ status: OSStatus) -> String {
        (SecCopyErrorMessageString(status, nil) as String?) ?? "OSStatus \(status)"
    }
}
