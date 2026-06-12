//
//  AuthenticatedUser.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import Foundation

/// Provider OAuth usado no login. RawValue string é o contrato com o backend.
enum AuthProvider: String, Codable {
    case apple
    case google

    var displayName: String {
        switch self {
        case .apple:  return "Apple"
        case .google: return "Google"
        }
    }
}

/// Sessão do usuário autenticado — é o objeto persistido no Keychain.
struct AuthenticatedUser: Codable, Equatable {
    let id: UUID
    let name: String?
    let email: String?
    let provider: AuthProvider
    let accessToken: String
}
