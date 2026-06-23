//
//  AuthError.swift
//  JordaniaTeamA
//

import Foundation

enum AuthError: Error {
    /// Erro genérico de autenticação com mensagem para a UI.
    case failed(String)
    /// O refresh token foi rejeitado pelo backend (expirado, revogado ou reuse detectado).
    /// Erro terminal: não retrytar, deslogar imediatamente.
    case sessionExpired
}
