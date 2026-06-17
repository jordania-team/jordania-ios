//
//  TaskItem.swift
//  AuthPlayground
//
//  Created by Rodrigo Borges on 01/06/26.
//  Ported to feature-based architecture.
//

import Foundation

struct TaskItem: Identifiable, Codable {
    let id: Int
    let title: String
    let description: String?
    let completed: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case title     = "titulo"
        case description = "descricao"
        case completed = "concluida"
        case createdAt = "criadaEm"
    }
}

struct CreateTaskRequest: Encodable {
    let titulo: String
    let descricao: String?
}
