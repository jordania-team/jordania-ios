//
//  TestURLSessionFactory.swift
//  JordaniaTeamIntegrationTests
//
//  Cria a URLSession de teste com MockURLProtocol registrado.
//  Usa `.ephemeral` para garantir zero cache, zero cookies, zero credenciais
//  persistidas entre testes.
//

import Foundation

enum TestURLSessionFactory {
    static func make() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
