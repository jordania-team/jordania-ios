//
//  JWTTests.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 01/07/26.
//

import Foundation
import Testing

@testable import JordaniaTeam

@Suite("JWT")
struct JWTTests {

    // MARK: - Helpers

    /// Gera um JWT sintético com `exp` definido manualmente.
    /// Permite controlar o tempo de expiração sem depender do relógio real.
    private func makeToken(exp: TimeInterval) -> String {
        let header  = #"{"alg":"HS256","typ":"JWT"}"#
        let payload = #"{"exp":\#(Int(exp))}"#

        func encode(_ string: String) -> String {
            Data(string.utf8)
                .base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }

        return "\(encode(header)).\(encode(payload)).fakesignature"
    }

    // MARK: - isExpired

    /// Token expirado há 60s — deve ser considerado expirado.
    @Test func jwt_expiredToken_isExpiredReturnsTrue() {
        let token = makeToken(exp: Date().timeIntervalSince1970 - 60)
        #expect(JWT.isExpired(token) == true)
    }

    /// Token válido por mais 1h — não deve ser considerado expirado.
    @Test func jwt_validToken_isExpiredReturnsFalse() {
        let token = makeToken(exp: Date().timeIntervalSince1970 + 3600)
        #expect(JWT.isExpired(token) == false)
    }

    // MARK: - needsRefresh

    /// Token expira em 5 min — dentro da janela de 10 min, deve pedir refresh.
    @Test func jwt_tokenExpiresWithinSkew_needsRefreshReturnsTrue() {
        let token = makeToken(exp: Date().timeIntervalSince1970 + 300)
        #expect(JWT.needsRefresh(token) == true)
    }

    /// Token expira em 20 min — fora da janela de 10 min, não precisa de refresh.
    @Test func jwt_tokenExpiresOutsideSkew_needsRefreshReturnsFalse() {
        let token = makeToken(exp: Date().timeIntervalSince1970 + 1200)
        #expect(JWT.needsRefresh(token) == false)
    }

    /// Token expira exatamente em 600s — boundary é inclusivo (`< skew`), deve pedir refresh.
    @Test func jwt_tokenExpiresExactlyAtSkewBoundary_needsRefreshReturnsTrue() {
        let token = makeToken(exp: Date().timeIntervalSince1970 + 600)
        #expect(JWT.needsRefresh(token) == true)
    }

    // MARK: - Malformed

    /// JWT com segmentos inválidos — `isExpired` retorna `true` por não conseguir ler o `exp`.
    @Test func jwt_malformedToken_isExpiredReturnsTrue() {
        #expect(JWT.isExpired("not.a.valid.jwt.at.all") == true)
    }

    /// JWT sem separadores — `needsRefresh` retorna `true` por não conseguir ler o `exp`.
    @Test func jwt_malformedToken_needsRefreshReturnsTrue() {
        #expect(JWT.needsRefresh("notajwt") == true)
    }
}
