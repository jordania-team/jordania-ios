//
//  TasksView.swift
//  JordaniaTeamA
//
//  Created by Rodrigo Borges on 01/06/26.
//  Ported to feature-based architecture.
//

import SwiftUI

struct TasksView: View {

    @State private var viewModel: TasksViewModel
    private let onSignOut: () -> Void

    init(apiClient: APIClient, onSignOut: @escaping () -> Void) {
        _viewModel = State(
            initialValue: TasksViewModel(
                service: TasksService(apiClient: apiClient)
            )
        )
        self.onSignOut = onSignOut
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                createForm

                if viewModel.isLoading {
                    ProgressView("Loading...")
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        // TODO: substituir por BrandColors.error quando disponível
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                taskList
            }
            .padding()
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Reload") {
                        Task { await viewModel.loadTasks() }
                    }
                    Button("Sign Out", role: .destructive, action: onSignOut)
                }
            }
            .task {
                await viewModel.loadTasks()
            }
        }
    }

    private var createForm: some View {
        VStack(spacing: 8) {
            TextField("Title", text: $viewModel.title)
                .textFieldStyle(.roundedBorder)
            TextField("Description (optional)", text: $viewModel.taskDescription)
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await viewModel.createTask() }
            } label: {
                Text("Create task")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var taskList: some View {
        List {
            ForEach(viewModel.tasks) { task in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(task.title)
                            .font(.headline)
                        Spacer()
                        Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(task.completed ? .green : .secondary)
                    }

                    if let description = task.description, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        if !task.completed {
                            Button("Complete") {
                                Task { await viewModel.completeTask(task) }
                            }
                            .buttonStyle(.bordered)
                        }
                        Button("Delete", role: .destructive) {
                            Task { await viewModel.deleteTask(task) }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
    }
}
