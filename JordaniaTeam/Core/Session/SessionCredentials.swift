//
//  SessionCredentials.swift
//  JordaniaTeam
//

import Foundation

struct SessionCredentials: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
    let refreshExpiresAt: Date

    var accessExpiresAt: Date? {
        JWT.expirationDate(of: accessToken)
    }

    var accessExpiresIn: TimeInterval? {
        accessExpiresAt?.timeIntervalSinceNow
    }

    var refreshExpiresIn: TimeInterval {
        refreshExpiresAt.timeIntervalSinceNow
    }

    var isAccessExpired: Bool {
        JWT.isExpired(accessToken)
    }

    var isRefreshExpired: Bool {
        refreshExpiresAt <= Date()
    }

    var accessClaims: JWTClaims? {
        JWT.claims(of: accessToken)
    }

    var maskedAccessToken: String {
        TokenMask.mask(accessToken)
    }

    var maskedRefreshToken: String {
        TokenMask.mask(refreshToken)
    }
}

struct SessionDebugSnapshot: Equatable, Sendable {
    let hasSession: Bool
    let hasCredentials: Bool
    let hasLegacyAccessToken: Bool
    let accessTokenMasked: String?
    let refreshTokenMasked: String?
    let accessExpiresAt: Date?
    let refreshExpiresAt: Date?
    let accessClaims: JWTClaims?
}

enum TokenMask {
    static func mask(_ token: String) -> String {
        guard !token.isEmpty else { return "<empty>" }
        if token.count <= 16 {
            return "\(token.prefix(4))..."
        }
        return "\(token.prefix(8))...\(token.suffix(8))"
    }
}
