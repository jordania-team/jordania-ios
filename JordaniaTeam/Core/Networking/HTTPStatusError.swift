//
//  HTTPStatusError.swift
//  JordaniaTeam
//

import Foundation

struct HTTPStatusError: LocalizedError, Equatable {
    let requestDescription: String
    let statusCode: Int
    let body: String?

    var errorDescription: String? {
        debugMessage
    }

    var debugMessage: String {
        var message = "\(requestDescription) -> HTTP \(statusCode)"
        if let bodySnippet, !bodySnippet.isEmpty {
            message += "\n\(bodySnippet)"
        }
        return message
    }

    private var bodySnippet: String? {
        guard let body else { return nil }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.count <= 2_000 {
            return trimmed
        }
        return String(trimmed.prefix(2_000)) + "..."
    }
}
