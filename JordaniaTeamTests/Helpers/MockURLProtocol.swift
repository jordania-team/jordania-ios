//
//  MockURLProtocol.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 02/07/26.
//

import Foundation

/// URLProtocol que intercepta todos os requests durante os testes.
/// Configura a resposta via `requestHandler` antes de cada teste.
final class MockURLProtocol: URLProtocol {

    /// Handler configurado pelo teste: recebe o request e retorna (response, data) ou lança.
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
