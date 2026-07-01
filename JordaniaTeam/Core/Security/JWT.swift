//
//  JWT.swift
//  JordaniaTeamA
//
//  Created by Gabriel Ferrari on 12/06/26.
//

import Foundation

/// Leitura local de claims do JWT — apenas para decisões de UX (ex: refresh proativo antes de expirar).
/// A validação real de assinatura é sempre do backend.
nonisolated enum JWT {

    /// Margem de segurança: token a menos de 30 s de expirar é tratado como expirado,
    /// evitando 401 na primeira chamada após o launch.
    private static let expirationLeeway: TimeInterval = 30

    /// Retorna true se o token já expirou (com leeway de 30 s).
    static func isExpired(_ token: String) -> Bool {
        guard let expiration = expirationDate(of: token) else { return true }
        return expiration.timeIntervalSinceNow < expirationLeeway
    }

    /// Retorna true se o token expira dentro de `skew` segundos.
    ///
    /// Usado para refresh proativo: o TokenProvider dispara o refresh antes que o
    /// access token expire, eliminando 401 em chamadas paralelas.
    ///
    /// - Parameter skew: margem configuravel; default 600 s (10 min).
    ///   Não tratar o exp local como autoridade absoluta — o backend valida a assinatura.
    static func needsRefresh(_ token: String, skew: TimeInterval = 600) -> Bool {
        guard let expiration = expirationDate(of: token) else { return true }
        return expiration.timeIntervalSinceNow < skew
    }

    // MARK: - Private

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
