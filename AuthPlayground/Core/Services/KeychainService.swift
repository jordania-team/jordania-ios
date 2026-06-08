//
//  KeychainService.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 07/06/26.
//

import Foundation
import Security

/// Wrapper mínimo sobre o Security framework para persistir strings no Keychain.
/// Sem abstrações desnecessárias — resolve exatamente o que o projeto precisa.
enum KeychainService {

    // MARK: - Public API

    /// Salva ou atualiza um valor string para a chave informada.
    @discardableResult
    static func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrAccount:    key,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]

        let attributes: [CFString: Any] = [kSecValueData: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var insertQuery = query
            insertQuery[kSecValueData] = data
            return SecItemAdd(insertQuery as CFDictionary, nil) == errSecSuccess
        }

        return updateStatus == errSecSuccess
    }

    /// Lê o valor string associado à chave. Retorna nil se não existir.
    static func read(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return nil }

        return value
    }

    /// Remove o valor associado à chave. No-op silencioso se não existir.
    @discardableResult
    static func delete(forKey key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
