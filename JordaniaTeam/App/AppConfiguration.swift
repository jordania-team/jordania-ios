//
//  AppConfiguration.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 11/06/26.
//

import Foundation

/// Centraliza as configurações de ambiente da aplicação.
enum AppConfiguration {

    static let apiBaseURL: URL = {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
            !raw.isEmpty,
            let url = URL(string: raw)
        else {
            preconditionFailure("API_BASE_URL ausente ou inválida no Info.plist")
        }
        print("API URL:", url) // remover depois
        return url
    }()
}
