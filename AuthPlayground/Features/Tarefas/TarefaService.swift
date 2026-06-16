//
//  TarefaService.swift
//  AuthPlayground
//
//  Created by Rodrigo Borges on 01/06/26.
//  Ported and adapted: token read from SessionStore instead of injected directly.
//

import Foundation

/// Responsável pelas chamadas HTTP para o endpoint /api/tarefas.
/// Recebe o accessToken no init — fornecido pelo SessionStore.
final class TarefaService {

    private let baseURL = AppConfiguration.apiBaseURL.appendingPathComponent("api")
    private let keychain: KeychainService

    init(keychain: KeychainService = KeychainService()) {
        self.keychain = keychain
    }

    func listar() async throws -> [Tarefa] {
        let url = baseURL.appendingPathComponent("tarefas")
        let (data, response) = try await URLSession.shared.data(for: try autenticado(url: url, method: "GET"))
        try validar(response)
        return try decodificar([Tarefa].self, from: data)
    }

    func criar(titulo: String, descricao: String?) async throws -> Tarefa {
        let url = baseURL.appendingPathComponent("tarefas")
        let body = try JSONEncoder().encode(CriarTarefaRequest(titulo: titulo, descricao: descricao))
        var request = try autenticado(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response) = try await URLSession.shared.data(for: request)
        try validar(response)
        return try decodificar(Tarefa.self, from: data)
    }

    func concluir(id: Int) async throws -> Tarefa {
        let url = baseURL
            .appendingPathComponent("tarefas")
            .appendingPathComponent(String(id))
            .appendingPathComponent("concluir")
        let (data, response) = try await URLSession.shared.data(for: try autenticado(url: url, method: "PATCH"))
        try validar(response)
        return try decodificar(Tarefa.self, from: data)
    }

    func deletar(id: Int) async throws {
        let url = baseURL
            .appendingPathComponent("tarefas")
            .appendingPathComponent(String(id))
        let (_, response) = try await URLSession.shared.data(for: try autenticado(url: url, method: "DELETE"))
        try validar(response)
    }

    // MARK: - Helpers

    private func autenticado(url: URL, method: String) throws -> URLRequest {
        guard let token = keychain.loadToken() else {
            throw NetworkError.unauthorized
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func validar(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        switch http.statusCode {
        case 200..<300: return
        case 401:       throw NetworkError.unauthorized
        default:        throw NetworkError.serverError(statusCode: http.statusCode)
        }
    }

    private func decodificar<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw NetworkError.decodingError
        }
    }
}
