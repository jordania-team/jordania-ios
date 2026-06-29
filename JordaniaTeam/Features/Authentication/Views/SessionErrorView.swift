//
//  SessionErrorView.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 29/06/26.
//

import SwiftUI

/// Exibida quando a sessão falha ao ser validada.
/// Oferece ao usuário a opção de tentar novamente.
struct SessionErrorView: View {

    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Erro de sessão")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Tentar novamente", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
