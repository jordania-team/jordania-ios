//
//  JWT.swift
//  JordaniaTeamA
//
//  Created by Gabriel Ferrari on 12/06/26.
//

import Foundation

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

    private static func expirationDate(of token: String) -> Date? {
        let segments = token.split(separator: ".")
        guard segments.count == 3 else { return nil }

        var base64 = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }

        guard
            let payloadData = Data(base64Encoded: base64),
            let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
            let exp = payload["exp"] as? TimeInterval
        else { return nil }

        return Date(timeIntervalSince1970: exp)
    }
}
