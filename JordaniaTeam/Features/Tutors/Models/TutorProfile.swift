//
//  TutorProfile.swift
//  JordaniaTeam
//

import Foundation

struct TutorProfile: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let userId: UUID
    let name: String
    let username: String
    let isPrivate: Bool
    let imgURL: String?
    let birthday: String?
    let updatedAt: String
    let reportsCounter: Int

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case username
        case isPrivate = "is_private"
        case imgURL = "img_url"
        case birthday
        case updatedAt = "updated_at"
        case reportsCounter = "reports_counter"
    }
}

struct UpsertTutorRequest: Encodable, Sendable {
    let name: String
    let username: String
    let isPrivate: Bool
    let imgURL: String?
    let birthday: String?

    enum CodingKeys: String, CodingKey {
        case name
        case username
        case isPrivate = "is_private"
        case imgURL = "img_url"
        case birthday
    }
}
