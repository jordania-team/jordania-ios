//
//  JWT.swift
//  JordaniaTeamA
//
//  Created by Gabriel Ferrari on 12/06/26.
//

import Foundation

struct JWTClaims: Equatable, Sendable {
    let subject: String?
    let issuer: String?
    let issuedAt: Date?
    let expiresAt: Date?
    let provider: String?
    let role: String?
    let email: String?
    let name: String?

    var expiresIn: TimeInterval? {
        expiresAt?.timeIntervalSinceNow
    }
}

/// Leitura local de claims do JWT — apenas para decisões de UX (ex: não restaurar
/// sessão expirada no launch). A validação real de assinatura é sempre do backend.
enum JWT {

    /// Margem de segurança: token a segundos de expirar é tratado como expirado,
    /// evitando 401 na primeira chamada após o launch.
    private static let expirationLeeway: TimeInterval = 30

    static func isExpired(_ token: String) -> Bool {
        guard let expiration = expirationDate(of: token) else {
            // Token ilegível = inválido. Falha fechada, nunca aberta.
            return true
        }
        return expiration.timeIntervalSinceNow < expirationLeeway
    }

    static func expirationDate(of token: String) -> Date? {
        numericDateClaim("exp", in: token)
    }

    static func claims(of token: String) -> JWTClaims? {
        guard let payload = payload(of: token) else { return nil }

        return JWTClaims(
            subject: payload["sub"] as? String,
            issuer: payload["iss"] as? String,
            issuedAt: numericDate("iat", in: payload),
            expiresAt: numericDate("exp", in: payload),
            provider: payload["provider"] as? String,
            role: payload["role"] as? String,
            email: payload["email"] as? String,
            name: payload["name"] as? String
        )
    }

    static func payload(of token: String) -> [String: Any]? {
        let segments = token.split(separator: ".")
        guard segments.count == 3 else { return nil }

        var base64 = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }

        guard let payloadData = Data(base64Encoded: base64) else { return nil }
        return try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
    }

    private static func numericDateClaim(_ key: String, in token: String) -> Date? {
        guard let payload = payload(of: token) else { return nil }
        return numericDate(key, in: payload)
    }

    private static func numericDate(_ key: String, in payload: [String: Any]) -> Date? {
        if let value = payload[key] as? TimeInterval {
            return Date(timeIntervalSince1970: value)
        }
        if let value = payload[key] as? Int {
            return Date(timeIntervalSince1970: TimeInterval(value))
        }
        return nil
    }
}
