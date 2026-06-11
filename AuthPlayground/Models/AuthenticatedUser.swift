//
//  AuthenticatedUser.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import Foundation

/// Representa o usuário autenticado de forma agnóstica ao provider.
/// `Codable` é necessário para serialização no Keychain via JSONEncoder/JSONDecoder.
///
/// - Note: `accessToken` é o JWT emitido pelo backend Jordania — não o token do provider.
///   Armazenado exclusivamente no Keychain.
struct AuthenticatedUser: Codable {
    let id: UUID
    let name: String?
    let email: String?
    let provider: AuthProvider
    /// JWT do backend. Armazenado exclusivamente no Keychain.
    let accessToken: String
}

/// RawRepresentable e Codable para serialização como String.
enum AuthProvider: String, Codable {
    case apple
    case google
}
