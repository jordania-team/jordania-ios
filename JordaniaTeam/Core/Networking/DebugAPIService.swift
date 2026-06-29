//
//  DebugAPIService.swift
//  JordaniaTeam
//

import Foundation

final class DebugAPIService {

    private let apiClient: APIClient
    private let backendAuthService: BackendAuthService

    init(
        apiClient: APIClient,
        backendAuthService: BackendAuthService = BackendAuthService()
    ) {
        self.apiClient = apiClient
        self.backendAuthService = backendAuthService
    }

    func fetchCurrentUser() async throws -> HTTPDecodedResult<CurrentUserResponse> {
        let result = try await fetchCurrentUserDebug()
        guard let value = result.value else {
            throw HTTPStatusError(
                requestDescription: "GET /users/me",
                statusCode: result.statusCode,
                body: result.body
            )
        }
        return HTTPDecodedResult(statusCode: result.statusCode, body: result.body, value: value)
    }

    func fetchCurrentUserDebug() async throws -> HTTPDecodedResult<CurrentUserResponse?> {
        let url = AppConfiguration.apiBaseURL
            .appendingPathComponent("users")
            .appendingPathComponent("me")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let result = try await apiClient.performDebug(request)
        guard (200...299).contains(result.statusCode) else {
            return HTTPDecodedResult(statusCode: result.statusCode, body: result.body, value: nil)
        }

        return HTTPDecodedResult(
            statusCode: result.statusCode,
            body: result.body,
            value: Optional(try decode(CurrentUserResponse.self, from: result.data))
        )
    }

    func refreshDebug(refreshToken: String) async throws -> HTTPDebugResult {
        try await backendAuthService.refreshDebug(refreshToken: refreshToken)
    }

    func forceRefresh(refreshToken: String) async throws -> AuthSession {
        try await backendAuthService.refresh(refreshToken: refreshToken)
    }

    func usersMeWithoutToken() async throws -> HTTPDebugResult {
        try await backendAuthService.fetchMeDebug(accessToken: nil)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw NetworkError.decodingError
        }
    }
}
