//
//  UserServiceProtocol.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 02/07/26.
//

/// Abstração de acesso ao perfil do usuário autenticado.
/// Permite substituição por test doubles sem rede real.
protocol UserServiceProtocol: Sendable {
    func fetchCurrentUser() async throws -> AuthenticatedUser
}

extension UserService: UserServiceProtocol {}
