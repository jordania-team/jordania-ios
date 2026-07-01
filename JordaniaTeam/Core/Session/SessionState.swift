//
//  SessionState.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 29/06/26.
//

enum SessionState: Equatable {
    case loading
    case authenticated
    case signedOut
    case error(String)
}
