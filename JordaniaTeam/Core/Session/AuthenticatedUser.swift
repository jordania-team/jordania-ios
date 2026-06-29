//
//  AuthenticatedUser.swift
//  JordaniaTeamA
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import Foundation

/// Provider OAuth usado no login. RawValue string é o contrato com o backend.
enum AuthProvider: String, Codable, Sendable {
    case apple
    case google

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self).lowercased()
        guard let provider = AuthProvider(rawValue: value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Provider inválido: \(value)"
            )
        }
        self = provider
    }

    var displayName: String {
        switch self {
        case .apple:  return "Apple"
        case .google: return "Google"
        }
    }
}

/// Role retornado pelo backend. O decoder aceita caixa diferente porque o backend
/// usa Java enum `.name()`, que pode serializar como TUTOR/ADMIN.
enum UserRole: String, Codable, Sendable {
    case tutor
    case admin

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self).lowercased()
        guard let role = UserRole(rawValue: value) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Role inválido: \(value)"
            )
        }
        self = role
    }
}

/// Sessão do usuário autenticado — é o objeto persistido no Keychain.
/// O JWT não faz parte deste modelo: vive isolado no Keychain e é lido
/// exclusivamente pelo APIClient no momento de cada request.
struct AuthenticatedUser: Codable, Equatable, Sendable {
    let id: UUID
    let name: String?
    let email: String?
    let provider: AuthProvider
    let role: UserRole
}
