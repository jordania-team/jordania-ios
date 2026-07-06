//
//  AuthFixtures.swift
//  JordaniaTeamIntegrationTests
//
//  Helpers que carregam os JSONs de fixtures e constroem HTTPURLResponse prontos
//  para uso nos requestHandlers do MockURLProtocol.
//
//  Uso:
//    MockURLProtocol.requestHandler = { _ in
//        AuthFixtures.successResponse(for: "https://example.com/auth/login")
//    }
//

import Foundation
@testable import JordaniaTeam

enum AuthFixtures {

    // MARK: - Respostas prontas

    static func successResponse(for urlString: String) -> (HTTPURLResponse, Data) {
        response(statusCode: 200, json: successJSON, for: urlString)
    }

    static func unauthorizedResponse(for urlString: String) -> (HTTPURLResponse, Data) {
        response(statusCode: 401, json: unauthorizedJSON, for: urlString)
    }

    static func serverErrorResponse(for urlString: String) -> (HTTPURLResponse, Data) {
        response(statusCode: 500, json: serverErrorJSON, for: urlString)
    }

    static func invalidPayloadResponse(for urlString: String) -> (HTTPURLResponse, Data) {
        response(statusCode: 200, json: invalidPayloadJSON, for: urlString)
    }

    // MARK: - Helpers de token

    /// JWT de exemplo com expiração no futuro (exp: ano 2099).
    /// Header.Payload.Signature — estrutura válida para JWT.isExpired().
    static let validAccessToken: String = {
        // payload: {"sub":"test-user","exp":4102444800} (2099-12-31)
        let header  = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        let payload = "eyJzdWIiOiJ0ZXN0LXVzZXIiLCJleHAiOjQxMDI0NDQ4MDB9"
        let sig     = "SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        return "\(header).\(payload).\(sig)"
    }()

    static let expiredAccessToken: String = {
        // payload: {"sub":"test-user","exp":1} (passado)
        let header  = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        let payload = "eyJzdWIiOiJ0ZXN0LXVzZXIiLCJleHAiOjF9"
        let sig     = "SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        return "\(header).\(payload).\(sig)"
    }()

    static let validRefreshToken = "refresh-token-de-teste-valido"

    static let testUserID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    // MARK: - Private — JSONs

    private static var successJSON: String {
        """
        {
          "token": "\(validAccessToken)",
          "userId": "\(testUserID.uuidString)",
          "name": "Test User",
          "email": "test@jordania.com",
          "refreshToken": "\(validRefreshToken)",
          "refreshExpiresAt": "2099-12-31T23:59:59Z"
        }
        """
    }

    private static let unauthorizedJSON   = "{\"error\": \"Unauthorized\"}"
    private static let serverErrorJSON    = "{\"error\": \"Internal Server Error\"}"
    private static let invalidPayloadJSON = "{\"unexpected_field\": true}"

    // MARK: - Builder

    private static func response(
        statusCode: Int,
        json: String,
        for urlString: String
    ) -> (HTTPURLResponse, Data) {
        let url  = URL(string: urlString)!
        let http = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        let data = Data(json.utf8)
        return (http, data)
    }
}
