//
//  AuthError.swift
//  JordaniaTeamA
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import Foundation

/// Erros de domínio da autenticação. Erros de transporte/protocolo são NetworkError.
enum AuthError: LocalizedError, Equatable {
    /// Usuário cancelou o fluxo — a UI ignora silenciosamente (errorDescription nil).
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled:           return nil
        case .failed(let message): return message
        }
    }
}
