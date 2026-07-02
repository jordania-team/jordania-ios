//
//  BackendAuthServiceProtocol.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 02/07/26.
//

/// Abstração das chamadas de autenticação ao backend.
/// Permite substituição por test doubles sem rede real.
protocol BackendAuthServiceProtocol: Sendable {
    func refresh(refreshToken: String) async throws -> AuthSession
}

extension BackendAuthService: BackendAuthServiceProtocol {}
