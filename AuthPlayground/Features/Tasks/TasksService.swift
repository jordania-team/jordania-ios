//
//  TasksService.swift
//  AuthPlayground
//
//  Created by Rodrigo Borges on 01/06/26.
//  Ported and adapted: token read from SessionStore instead of injected directly.
//

import Foundation

final class TasksService {

    private let baseURL = AppConfiguration.apiBaseURL.appendingPathComponent("api")
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchAll() async throws -> [TaskItem] {
        let data = try await apiClient.perform(buildRequest(url: taskURL(), method: "GET"))
        return try decode([TaskItem].self, from: data)
    }

    func create(title: String, description: String?) async throws -> TaskItem {
        var request = buildRequest(url: taskURL(), method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(CreateTaskRequest(titulo: title, descricao: description))
        let data = try await apiClient.perform(request)
        return try decode(TaskItem.self, from: data)
    }

    func complete(id: Int) async throws -> TaskItem {
        let url = taskURL(id: id).appendingPathComponent("concluir")
        let data = try await apiClient.perform(buildRequest(url: url, method: "PATCH"))
        return try decode(TaskItem.self, from: data)
    }

    func delete(id: Int) async throws {
        _ = try await apiClient.perform(buildRequest(url: taskURL(id: id), method: "DELETE"))
    }

    private func taskURL(id: Int? = nil) -> URL {
        let base = baseURL.appendingPathComponent("tarefas")
        guard let id else { return base }
        return base.appendingPathComponent(String(id))
    }

    private func buildRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        return request
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw NetworkError.decodingError
        }
    }
}
