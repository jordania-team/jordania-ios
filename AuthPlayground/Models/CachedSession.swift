//
//  CachedSession.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import Foundation
import SwiftData

/// Modelo persistido localmente com SwiftData.
/// Armazena apenas dados de perfil não-sensíveis.
/// Tokens de autenticação NUNCA devem ser armazenados aqui — use Keychain para isso.
@Model
final class CachedSession {
    var userID: String
    var name: String?
    var email: String?
    var providerRaw: String
    var createdAt: Date

    init(
        userID: String,
        name: String?,
        email: String?,
        provider: AuthProvider
    ) {
        self.userID = userID
        self.name = name
        self.email = email
        self.providerRaw = provider.rawValue
        self.createdAt = .now
    }

    var provider: AuthProvider {
        AuthProvider(rawValue: providerRaw) ?? .apple
    }

    /// Converte para o modelo de domínio agnóstico usado pela UI.
    func toAuthenticatedUser() -> AuthenticatedUser {
        AuthenticatedUser(
            id: userID,
            name: name,
            email: email,
            provider: provider
        )
    }
}
