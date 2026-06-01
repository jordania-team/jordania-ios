//
//  AuthenticatedUser.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import Foundation

/// Representa o usuário autenticado de forma agnóstica ao provider.
/// A View e a SessionStore nunca dependem de Apple ou Google diretamente.
struct AuthenticatedUser {
    let id: String
    let name: String?
    let email: String?
    let provider: AuthProvider
}

enum AuthProvider {
    case apple
    case google
}
