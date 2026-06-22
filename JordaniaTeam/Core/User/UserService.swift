//
//  UserService.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 19/06/26.
//

import Foundation

struct UserService {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchCurrentUser() async throws -> AuthenticatedUser {
        let url = AppConfiguration.apiBaseURL
            .appendingPathComponent("users")
            .appendingPathComponent("me")

        let request = URLRequest(url: url)
        let data = try await apiClient.perform(request)
        let response = try JSONDecoder().decode(UserMeResponse.self, from: data)
        return response.toAuthenticatedUser()
    }
}

// MARK: - DTO

private struct UserMeResponse: Decodable {
    let userId: UUID
    let name: String?
    let email: String?
    let provider: AuthProvider

    func toAuthenticatedUser() -> AuthenticatedUser {
        AuthenticatedUser(id: userId, name: name, email: email, provider: provider)
    }
}
