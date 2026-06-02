//
//  CachedSession.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import Foundation
import SwiftData

/// Modelo persistido localmente com SwiftData.
/// Armazena dados de perfil não-sensíveis.
///
/// - Warning: `accessTokenRaw` é armazenado aqui apenas para a spike/POC.
///   Em produção, tokens de autenticação DEVEM ser armazenados exclusivamente no Keychain.
@Model
final class CachedSession {
    var userID: String
    var name: String?
    var email: String?
    var providerRaw: String
    var createdAt: Date
    /// JWT do backend. TODO: Remover daqui e migrar para Keychain antes de produção.
    var accessTokenRaw: String

    init(
        userID: String,
        name: String?,
        email: String?,
        provider: AuthProvider,
        accessToken: String
    ) {
        self.userID = userID
        self.name = name
        self.email = email
        self.providerRaw = provider.rawValue
        self.createdAt = .now
        self.accessTokenRaw = accessToken
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
            provider: provider,
            accessToken: accessTokenRaw
        )
    }
}
