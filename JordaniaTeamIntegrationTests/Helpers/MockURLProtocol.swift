//
//  MockURLProtocol.swift
//  JordaniaTeamIntegrationTests
//
//  Intercepta todas as requisições URLSession dentro dos integration tests.
//  Substitui o socket real por um closure determinístico — nenhuma chamada de rede
//  sai do processo durante os testes.
//
//  Uso:
//    MockURLProtocol.requestHandler = { request in
//        let response = HTTPURLResponse(url: request.url!, statusCode: 200, ...)
//        return (response, jsonData)
//    }
//

import Foundation

final class MockURLProtocol: URLProtocol, @unchecked Sendable {

    /// Closure chamada para cada request. Define status code + body.
    /// Se nil, o request falha com `.badServerResponse`.
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
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
