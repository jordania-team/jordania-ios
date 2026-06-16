//
//  Tarefa.swift
//  AuthPlayground
//
//  Created by Rodrigo Borges on 01/06/26.
//  Ported to feature-based architecture.
//

import Foundation

struct Tasks: Identifiable, Codable {
    let id: Int
    let titulo: String
    let descricao: String?
    let concluida: Bool
    let criadaEm: String
}

struct CriarTarefaRequest: Encodable {
    let titulo: String
    let descricao: String?
}
