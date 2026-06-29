//
//  TutorsService.swift
//  JordaniaTeam
//

import Foundation

enum TutorsServiceError: LocalizedError, Equatable {
    case invalidFields(details: String?)
    case usernameAlreadyExists(details: String?)

    var errorDescription: String? {
        switch self {
        case .invalidFields(let details):
            return message("Campos inválidos. Revise os dados do tutor.", details: details)
        case .usernameAlreadyExists(let details):
            return message("Este username já está em uso.", details: details)
        }
    }

    private func message(_ title: String, details: String?) -> String {
        guard let details, !details.isEmpty else { return title }
        return "\(title)\n\(details)"
    }
}

final class TutorsService {

    private let baseURL = AppConfiguration.apiBaseURL.appendingPathComponent("api")
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchMe() async throws -> TutorProfile? {
        let result = try await fetchMeDebug()
        switch result.statusCode {
        case 200...299:
            return result.value
        case 404:
            return nil
        case 401:
            throw NetworkError.unauthorized
        default:
            throw HTTPStatusError(
                requestDescription: "GET /api/tutors/me",
                statusCode: result.statusCode,
                body: result.body
            )
        }
    }

    func fetchMeDebug() async throws -> HTTPDecodedResult<TutorProfile?> {
        let result = try await apiClient.performDebug(buildRequest(url: tutorURL(), method: "GET"))

        if result.statusCode == 404 {
            return HTTPDecodedResult(statusCode: result.statusCode, body: result.body, value: nil)
        }

        guard (200...299).contains(result.statusCode) else {
            return HTTPDecodedResult(statusCode: result.statusCode, body: result.body, value: nil)
        }

        do {
            return HTTPDecodedResult(
                statusCode: result.statusCode,
                body: result.body,
                value: Optional(try decode(TutorProfile.self, from: result.data))
            )
        } catch {
            throw error
        }
    }

    func upsertMe(_ requestBody: UpsertTutorRequest) async throws -> TutorProfile {
        let result = try await upsertMeDebug(requestBody)
        if let tutor = result.value, (200...299).contains(result.statusCode) {
            return tutor
        }

        if result.statusCode == 400 {
            throw TutorsServiceError.invalidFields(details: result.body)
        }
        if result.statusCode == 409 {
            throw TutorsServiceError.usernameAlreadyExists(details: result.body)
        }
        if result.statusCode == 401 {
            throw NetworkError.unauthorized
        }

        throw HTTPStatusError(
            requestDescription: "PUT /api/tutors/me",
            statusCode: result.statusCode,
            body: result.body
        )
    }

    func upsertMeDebug(_ requestBody: UpsertTutorRequest) async throws -> HTTPDecodedResult<TutorProfile?> {
        var request = buildRequest(url: tutorURL(), method: "PUT")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw NetworkError.encodingError
        }

        let result = try await apiClient.performDebug(request)

        guard (200...299).contains(result.statusCode) else {
            return HTTPDecodedResult(statusCode: result.statusCode, body: result.body, value: nil)
        }

        return HTTPDecodedResult(
            statusCode: result.statusCode,
            body: result.body,
            value: Optional(try decode(TutorProfile.self, from: result.data))
        )
    }

    func uploadProfileImageDebug(
        imageData: Data,
        filename: String,
        mimeType: String
    ) async throws -> HTTPDecodedResult<TutorProfile?> {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = buildRequest(url: profileImageURL(), method: "POST")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(
            boundary: boundary,
            fieldName: "file",
            filename: filename,
            mimeType: mimeType,
            fileData: imageData
        )

        let result = try await apiClient.performDebug(request)

        guard (200...299).contains(result.statusCode) else {
            return HTTPDecodedResult(statusCode: result.statusCode, body: result.body, value: nil)
        }

        return HTTPDecodedResult(
            statusCode: result.statusCode,
            body: result.body,
            value: Optional(try decode(TutorProfile.self, from: result.data))
        )
    }

    func deleteProfileImageDebug() async throws -> HTTPDecodedResult<TutorProfile?> {
        let result = try await apiClient.performDebug(buildRequest(url: profileImageURL(), method: "DELETE"))

        guard (200...299).contains(result.statusCode) else {
            return HTTPDecodedResult(statusCode: result.statusCode, body: result.body, value: nil)
        }

        return HTTPDecodedResult(
            statusCode: result.statusCode,
            body: result.body,
            value: Optional(try decode(TutorProfile.self, from: result.data))
        )
    }

    private func tutorURL() -> URL {
        baseURL
            .appendingPathComponent("tutors")
            .appendingPathComponent("me")
    }

    private func profileImageURL() -> URL {
        tutorURL().appendingPathComponent("profile-image")
    }

    private func buildRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        return request
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw NetworkError.decodingError
        }
    }

    private func multipartBody(
        boundary: String,
        fieldName: String,
        filename: String,
        mimeType: String,
        fileData: Data
    ) -> Data {
        var body = Data()
        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n")
        body.appendUTF8("Content-Type: \(mimeType)\r\n\r\n")
        body.append(fileData)
        body.appendUTF8("\r\n--\(boundary)--\r\n")
        return body
    }
}

private extension Data {
    mutating func appendUTF8(_ string: String) {
        append(Data(string.utf8))
    }
}
