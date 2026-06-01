//
//  AuthenticatedUser.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import Foundation

/// Representa o usuário autenticado de forma agnóstica ao provider.
/// A View e a SessionStore nunca dependem de Apple ou Google diretamente.
///
/// - Note: `accessToken` é o JWT emitido pelo backend Jordania — não o token do provider.
///   Em produção, este token deve ser armazenado exclusivamente no Keychain.
struct AuthenticatedUser {
    let id: String
    let name: String?
    let email: String?
    let provider: AuthProvider
    /// JWT do backend. Usado em todas as chamadas autenticadas à API.
    /// TODO: Migrar para Keychain antes de produção.
    let accessToken: String
}

/// RawRepresentable para permitir persistência como String no SwiftData.
enum AuthProvider: String {
    case apple
    case google
}
