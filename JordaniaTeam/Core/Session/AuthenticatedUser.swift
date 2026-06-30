//
//  AuthenticatedUser.swift
//  JordaniaTeamA
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import Foundation

/// Provider OAuth usado no login. RawValue string é o contrato com o backend.
nonisolated enum AuthProvider: String, Codable {
    case apple
    case google

    // Tolerante a maíiusculas: o backend retorna "GOOGLE"/"APPLE", o iOS usa minúsculas internamente.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self).lowercased()
        guard let value = AuthProvider(rawValue: raw) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot initialize AuthProvider from invalid String value \(raw)"
            )
        }
        self = value
    }

    var displayName: String {
        switch self {
        case .apple:  return "Apple"
        case .google: return "Google"
        }
    }
}

/// Sessão do usuário autenticado — é o objeto persistido no Keychain.
/// O JWT não faz parte deste modelo: vive isolado no Keychain e é lido
/// exclusivamente pelo APIClient no momento de cada request.
nonisolated struct AuthenticatedUser: Codable, Equatable {
    let id: UUID
    let name: String?
    let email: String?
    let provider: AuthProvider
}
