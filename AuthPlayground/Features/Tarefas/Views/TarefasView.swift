//
//  TarefasView.swift
//  AuthPlayground
//
//  Created by Rodrigo Borges on 01/06/26.
//  Ported to feature-based architecture.
//

import SwiftUI

struct TarefasView: View {

    @StateObject private var viewModel: TarefasViewModel
    private let onSignOut: () -> Void

    /// accessToken vem do SessionStore — fornecido pelo caller (AuthPlaygroundApp ou ContentView).
    init(sessionStore: SessionStore, onSignOut: @escaping () -> Void) {
        _viewModel = StateObject(
            wrappedValue: TarefasViewModel(
                service: TarefaService(keychain: KeychainService())
            )
        )
        self.onSignOut = onSignOut
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                formulario

                if viewModel.carregando {
                    ProgressView("Carregando...")
                }

                if let erro = viewModel.mensagemErro {
                    Text(erro)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                lista
            }
            .padding()
            .navigationTitle("Tarefas")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Recarregar") {
                        Task { await viewModel.carregarTarefas() }
                    }
                    Button("Sair", role: .destructive, action: onSignOut)
                }
            }
            .task {
                await viewModel.carregarTarefas()
            }
        }
    }

    private var formulario: some View {
        VStack(spacing: 8) {
            TextField("Título", text: $viewModel.titulo)
                .textFieldStyle(.roundedBorder)
            TextField("Descrição (opcional)", text: $viewModel.descricao)
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await viewModel.criarTarefa() }
            } label: {
                Text("Criar tarefa")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var lista: some View {
        List {
            ForEach(viewModel.tarefas) { tarefa in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(tarefa.titulo)
                            .font(.headline)
                        Spacer()
                        Image(systemName: tarefa.concluida ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(tarefa.concluida ? .green : .secondary)
                    }

                    if let descricao = tarefa.descricao, !descricao.isEmpty {
                        Text(descricao)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        if !tarefa.concluida {
                            Button("Concluir") {
                                Task { await viewModel.concluirTarefa(tarefa) }
                            }
                            .buttonStyle(.bordered)
                        }
                        Button("Excluir", role: .destructive) {
                            Task { await viewModel.deletarTarefa(tarefa) }
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
