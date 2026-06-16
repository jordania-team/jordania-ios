//
//  TarefaService.swift
//  AuthPlayground
//
//  Created by Rodrigo Borges on 01/06/26.
//  Ported and adapted: token read from SessionStore instead of injected directly.
//

import Foundation

/// Responsável pelas chamadas HTTP para o endpoint /api/tarefas.
/// Token, 401 e refresh são tratados pelo APIClient — este service só monta requests.
final class TarefaService {

    private let baseURL = AppConfiguration.apiBaseURL.appendingPathComponent("api")
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func listar() async throws -> [Tarefa] {
        let data = try await apiClient.perform(buildRequest(url: baseURL.appendingPathComponent("tarefas"), method: "GET"))
        return try decodificar([Tarefa].self, from: data)
    }

    func criar(titulo: String, descricao: String?) async throws -> Tarefa {
        let url = baseURL.appendingPathComponent("tarefas")
        var request = buildRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(CriarTarefaRequest(titulo: titulo, descricao: descricao))
        let data = try await apiClient.perform(request)
        return try decodificar(Tarefa.self, from: data)
    }

    func concluir(id: Int) async throws -> Tarefa {
        let url = baseURL
            .appendingPathComponent("tarefas")
            .appendingPathComponent(String(id))
            .appendingPathComponent("concluir")
        let data = try await apiClient.perform(buildRequest(url: url, method: "PATCH"))
        return try decodificar(Tarefa.self, from: data)
    }

    func deletar(id: Int) async throws {
        let url = baseURL
            .appendingPathComponent("tarefas")
            .appendingPathComponent(String(id))
        _ = try await apiClient.perform(buildRequest(url: url, method: "DELETE"))
    }

    // MARK: - Helpers

    private func buildRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        return request
    }

    private func decodificar<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw NetworkError.decodingError
        }
    }
}
