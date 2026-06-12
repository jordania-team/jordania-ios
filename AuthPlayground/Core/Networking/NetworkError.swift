//
//  NetworkError.swift
//  AuthPlayground
//
//  Created by Rodrigo Borges on 01/06/26.
//  Ported from APIError to Core/Networking following project architecture.
//

import Foundation

enum NetworkError: LocalizedError {
    case invalidResponse
    case unauthorized
    case decodingError
    case encodingError
    case serverError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:           return "Resposta inválida do servidor."
        case .unauthorized:              return "Sessão expirada. Faça login novamente."
        case .decodingError:             return "Erro ao interpretar dados do servidor."
        case .encodingError:             return "Erro ao preparar dados para envio."
        case .serverError(let code):     return "Erro no servidor (\(code))."
        }
    }
}
