//
//  TasksViewModel.swift
//  JordaniaTeamA
//
//  Created by Rodrigo Borges on 01/06/26.
//  Ported to feature-based architecture.
//

import Foundation
import OSLog

@Observable
@MainActor
final class TasksViewModel {

    private static let logger = Logger(subsystem: "app.jordania", category: "Tasks")

    var tasks: [TaskItem] = []
    var title: String = ""
    var taskDescription: String = ""
    var errorMessage: String?
    var isLoading: Bool = false

    // TODO: remover após validar o refresh token
    var pingResult: String?

    private let service: TasksService
    private let apiClient: APIClient

    init(service: TasksService, apiClient: APIClient) {
        self.service = service
        self.apiClient = apiClient
    }

    // TODO: remover após validar o refresh token
    func pingMe() async {
        pingResult = nil
        do {
            let user: AuthenticatedUser = try await apiClient.get("users/me")
            pingResult = "✅ /users/me OK — \(user.email ?? user.id.uuidString)"
            Self.logger.info("pingMe OK: userId=\(user.id)")
        } catch {
            pingResult = "❌ /users/me falhou: \(error)"
            Self.logger.error("pingMe falhou: \(error)")
        }
    }

    func loadTasks() async {
        isLoading = true
        errorMessage = nil
        do {
            tasks = try await service.fetchAll()
        } catch let error as NetworkError {
            Self.logger.error("loadTasks falhou: \(error)")
            errorMessage = error.errorDescription ?? "Não foi possível carregar as tarefas."
        } catch {
            Self.logger.error("loadTasks erro inesperado: \(error)")
            errorMessage = "Não foi possível carregar as tarefas."
        }
        isLoading = false
    }

    func createTask() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = taskDescription.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty else {
            errorMessage = "Digite um título para a tarefa."
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            let newTask = try await service.create(
                title: trimmedTitle,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription
            )
            tasks.insert(newTask, at: 0)
            title = ""
            taskDescription = ""
        } catch let error as NetworkError {
            Self.logger.error("createTask falhou: \(error)")
            errorMessage = error.errorDescription ?? "Não foi possível criar a tarefa."
        } catch {
            Self.logger.error("createTask erro inesperado: \(error)")
            errorMessage = "Não foi possível criar a tarefa."
        }
        isLoading = false
    }

    func completeTask(_ task: TaskItem) async {
        isLoading = true
        errorMessage = nil
        do {
            let updated = try await service.complete(id: task.id)
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[index] = updated
            }
        } catch let error as NetworkError {
            Self.logger.error("completeTask(\(task.id)) falhou: \(error)")
            errorMessage = error.errorDescription ?? "Não foi possível concluir a tarefa."
        } catch {
            Self.logger.error("completeTask(\(task.id)) erro inesperado: \(error)")
            errorMessage = "Não foi possível concluir a tarefa."
        }
        isLoading = false
    }

    func deleteTask(_ task: TaskItem) async {
        isLoading = true
        errorMessage = nil
        do {
            try await service.delete(id: task.id)
            tasks.removeAll { $0.id == task.id }
        } catch let error as NetworkError {
            Self.logger.error("deleteTask(\(task.id)) falhou: \(error)")
            errorMessage = error.errorDescription ?? "Não foi possível excluir a tarefa."
        } catch {
            Self.logger.error("deleteTask(\(task.id)) erro inesperado: \(error)")
            errorMessage = "Não foi possível excluir a tarefa."
        }
        isLoading = false
    }
}
