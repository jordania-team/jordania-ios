//
//  SessionPersistence.swift
//  AuthPlayground
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import Foundation
import SwiftData

/// Responsável exclusivamente por ler e escrever a sessão no SwiftData.
/// A SessionStore delega persistência para cá, sem conhecer SwiftData diretamente.
@MainActor
final class SessionPersistence {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Public API

    /// Retorna a sessão persistida, se existir.
    func loadSession() -> AuthenticatedUser? {
        let descriptor = FetchDescriptor<CachedSession>()
        let results = (try? modelContext.fetch(descriptor)) ?? []
        return results.first?.toAuthenticatedUser()
    }

    /// Persiste a sessão do usuário autenticado.
    /// Apaga qualquer sessão anterior antes de salvar.
    func save(_ user: AuthenticatedUser) {
        clearAll()
        let session = CachedSession(
            userID: user.id,
            name: user.name,
            email: user.email,
            provider: user.provider
        )
        modelContext.insert(session)
        try? modelContext.save()
    }

    /// Apaga a sessão persistida.
    func clearAll() {
        let descriptor = FetchDescriptor<CachedSession>()
        let results = (try? modelContext.fetch(descriptor)) ?? []
        results.forEach { modelContext.delete($0) }
        try? modelContext.save()
    }
}
