//
//  AuthError.swift
//  JordaniaTeamA
//

import Foundation

enum AuthError: Error {
    /// Erro genérico de autenticação com mensagem para a UI.
    case failed(String)
    /// O usuário cancelou o fluxo de autenticação (ex: dismissou o sheet da Apple).
    case cancelled
    /// O refresh token foi rejeitado pelo backend (expirado, revogado ou reuse detectado).
    /// Erro terminal: não retrytar, deslogar imediatamente.
    case sessionExpired
}

extension AuthError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .failed(let message): return message
        case .cancelled:           return nil
        case .sessionExpired:      return "Sua sessão expirou. Faça login novamente."
        }
    }
}
