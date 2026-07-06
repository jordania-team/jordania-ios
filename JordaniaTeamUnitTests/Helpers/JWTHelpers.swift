//
//  JWTHelpers.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 02/07/26.
//

import Foundation

/// Gera um JWT mínimo com `exp` calculado a partir de agora + offset em segundos.
/// Não é assinado — apenas estrutura válida para os testes de parsing.
func makeJWT(expiresInSeconds offset: TimeInterval) -> String {
    let exp = Int(Date().timeIntervalSince1970) + Int(offset)
    let payload = #"{"exp":\#(exp)}"#
    let encoded = Data(payload.utf8).base64EncodedString()
        .replacingOccurrences(of: "=", with: "")
    return "header.\(encoded).signature"
}
