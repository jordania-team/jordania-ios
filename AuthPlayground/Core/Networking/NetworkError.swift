//
//  NetworkError.swift
//  AuthPlayground
//
//  Created by Rodrigo Borges on 01/06/26.
//  Ported from APIError to Core/Networking following project architecture.
//

import Foundation

/// Erros de transporte e protocolo HTTP. Erros de dominio (ex: AuthError) ficam nas features.
/// Status codes e detalhes tecnicos sao associated values para log/testes — nunca aparecem
/// no errorDescription, que e a mensagem exibida ao usuario.
enum NetworkError: LocalizedError, Equatable {
    case noConnection
    case timeout
    case cancelled
    case invalidResponse
    case unauthorized
    case decodingError
    case encodingError
    case serverError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .noConnection:    return "Sem conexão com a internet. Verifique sua rede."
        case .timeout:         return "O servidor demorou para responder. Tente novamente."
        case .cancelled:       return nil // cancelamento nao gera mensagem na UI
        case .invalidResponse: return "Resposta inválida do servidor."
        case .unauthorized:    return "Sessão expirada. Faça login novamente."
        case .decodingError:   return "Erro ao interpretar dados do servidor."
        case .encodingError:   return "Erro ao preparar dados para envio."
        case .serverError:     return "O servidor está indisponível no momento. Tente mais tarde."
        }
    }

    init(from urlError: URLError) {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
            self = .noConnection
        case .timedOut:
            self = .timeout
        case .cancelled:
            self = .cancelled
        default:
            self = .invalidResponse
        }
    }
}
