//
//  TarefasViewModel.swift
//  AuthPlayground
//
//  Created by Rodrigo Borges on 01/06/26.
//  Ported to feature-based architecture.
//

import Foundation

@MainActor
final class TarefasViewModel: ObservableObject {

    @Published var tarefas: [Tarefa] = []
    @Published var titulo: String = ""
    @Published var descricao: String = ""
    @Published var mensagemErro: String?
    @Published var carregando: Bool = false

    private let service: TarefaService

    init(service: TarefaService) {
        self.service = service
    }

    func carregarTarefas() async {
        carregando = true
        mensagemErro = nil
        do {
            tarefas = try await service.listar()
        } catch {
            mensagemErro = error.localizedDescription
        }
        carregando = false
    }

    func criarTarefa() async {
        let tituloLimpo = titulo.trimmingCharacters(in: .whitespacesAndNewlines)
        let descricaoLimpa = descricao.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !tituloLimpo.isEmpty else {
            mensagemErro = "Digite um título para a tarefa."
            return
        }

        carregando = true
        mensagemErro = nil
        do {
            let nova = try await service.criar(
                titulo: tituloLimpo,
                descricao: descricaoLimpa.isEmpty ? nil : descricaoLimpa
            )
            tarefas.insert(nova, at: 0)
            titulo = ""
            descricao = ""
        } catch {
            mensagemErro = error.localizedDescription
        }
        carregando = false
    }

    func concluirTarefa(_ tarefa: Tarefa) async {
        carregando = true
        mensagemErro = nil
        do {
            let atualizada = try await service.concluir(id: tarefa.id)
            if let index = tarefas.firstIndex(where: { $0.id == tarefa.id }) {
                tarefas[index] = atualizada
            }
        } catch {
            mensagemErro = error.localizedDescription
        }
        carregando = false
    }

    func deletarTarefa(_ tarefa: Tarefa) async {
        carregando = true
        mensagemErro = nil
        do {
            try await service.deletar(id: tarefa.id)
            tarefas.removeAll { $0.id == tarefa.id }
        } catch {
            mensagemErro = error.localizedDescription
        }
        carregando = false
    }
}
