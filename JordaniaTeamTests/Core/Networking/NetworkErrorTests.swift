//
//  NetworkErrorTests.swift
//  JordaniaTeamTests
//
//  Created by Gabriel Ferrari on 02/07/26.
//

import Foundation
import Testing

@testable import JordaniaTeam

@Suite("NetworkError")
struct NetworkErrorTests {

    @Test func networkError_urlError_notConnectedToInternet_mapsToNoConnection() {
        let error = NetworkError(from: URLError(.notConnectedToInternet))
        #expect(error == .noConnection)
    }

    @Test func networkError_urlError_timedOut_mapsToTimeout() {
        let error = NetworkError(from: URLError(.timedOut))
        #expect(error == .timeout)
    }

    @Test func networkError_urlError_cancelled_mapsToCancelled() {
        let error = NetworkError(from: URLError(.cancelled))
        #expect(error == .cancelled)
    }

    @Test func networkError_http500_mapsToServerError() {
        let error = NetworkError.serverError(statusCode: 500)
        #expect(error == .serverError(statusCode: 500))
    }

    @Test func networkError_http401_mapsToUnauthorized() {
        let error = NetworkError.unauthorized
        #expect(error == .unauthorized)
    }

    @Test func networkError_urlError_unknown_mapsToUnknown() {
        let error = NetworkError(from: URLError(.badServerResponse))
        #expect(error == .unknown)
    }
}
