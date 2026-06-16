//
//  AuthEndpoint.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 16/06/26.
//

import Foundation

/// Endpoints de autenticação usados pelo APIClient.
/// login fica no BackendAuthService — este arquivo é exclusivo para refresh.
enum AuthEndpoint {
    static func refresh(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        return request
    }
}
