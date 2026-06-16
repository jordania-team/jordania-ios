//
//  AppConfiguration.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 11/06/26.
//

import Foundation

/// Centraliza as configurações de ambiente da aplicação.
/// Em Debug aponta para o backend local, em Release para produção.
enum AppConfiguration {
    #if DEBUG
    static let apiBaseURL = URL(string: "http://10.40.57.27:8080")!
    #else
    static let apiBaseURL = URL(string: "https://api.redepets.xyz")!
    #endif
}
