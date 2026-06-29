//
//  SessionStore.swift
//  JordaniaTeamA
//
//  Created by Gabriel Ferrari on 31/05/26.
//

import Foundation
import Observation
import OSLog

struct AuthDebugEvent: Identifiable, Equatable {
    let id = UUID()
    let date = Date()
    let message: String
}

/// Fonte única de verdade do estado de autenticação.
/// Delega persistência para SessionPersistence — não conhece Keychain diretamente.
/// A POC expõe apenas dados mascarados/claims para debug.
@Observable
@MainActor
final class SessionStore {

    private static let logger = Logger(subsystem: "app.jordania", category: "Session")

    // MARK: - State

    private(set) var currentUser: AuthenticatedUser?
    private(set) var debugSnapshot: SessionDebugSnapshot
    private(set) var eventLog: [AuthDebugEvent] = []
    var lastAuthEvent: String?
    var lastLogoutStatus: String?
    var isLoading: Bool = false
    var authError: AuthError?

    // MARK: - Dependencies

    private let persistence: SessionPersistence

    // MARK: - Init

    init(persistence: SessionPersistence = SessionPersistence()) {
        self.persistence = persistence
        let user = persistence.loadSession()
        self.currentUser = user
        self.debugSnapshot = persistence.debugSnapshot(user: user)
        if user == nil {
            appendEvent("launch: no valid persisted session")
        } else {
            appendEvent("launch: restored persisted session")
        }
    }

    // MARK: - Computed

    var isSignedIn: Bool {
        currentUser != nil
    }

    var hasStoredToken: Bool {
        persistence.hasCredentials()
    }

    // MARK: - Actions

    func signIn(user: AuthenticatedUser, credentials: SessionCredentials) {
        isLoading = false
        authError = nil
        do {
            try persistence.save(user: user, credentials: credentials)
            currentUser = user
            refreshDebugSnapshot()
            recordAuthEvent("login: saved access+refresh credentials")
        } catch {
            authError = .failed("Não foi possível salvar a sessão com segurança.")
            recordAuthEvent("login: failed to save session")
        }
    }

    func updateCredentials(_ credentials: SessionCredentials, event: String) throws {
        try persistence.save(credentials: credentials)
        refreshDebugSnapshot()
        recordAuthEvent(event)
    }

    func replaceSession(user: AuthenticatedUser, credentials: SessionCredentials, event: String) throws {
        try persistence.save(user: user, credentials: credentials)
        currentUser = user
        refreshDebugSnapshot()
        recordAuthEvent(event)
    }

    func loadCredentials() -> SessionCredentials? {
        persistence.loadCredentials()
    }

    /// A UI sempre desloga, mesmo se a limpeza do Keychain falhar.
    func signOut() {
        isLoading = false
        currentUser = nil
        authError = nil
        do {
            try persistence.clearAll()
            refreshDebugSnapshot()
            recordAuthEvent("logout: local session cleared")
        } catch {
            Self.logger.fault("Logout: falha ao limpar o Keychain — token pode ter persistido.")
            refreshDebugSnapshot()
            recordAuthEvent("logout: local cleanup failed")
        }
    }

    func setError(_ error: AuthError) {
        isLoading = false
        authError = error
        recordAuthEvent("auth error: \(error.localizedDescription)")
    }

    func recordAuthEvent(_ event: String) {
        lastAuthEvent = event
        appendEvent(event)
    }

    func setLogoutStatus(_ status: String) {
        lastLogoutStatus = status
        appendEvent("logout remote: \(status)")
    }

    func refreshDebugSnapshot() {
        debugSnapshot = persistence.debugSnapshot(user: currentUser)
    }

    private func appendEvent(_ message: String) {
        eventLog.insert(AuthDebugEvent(message: message), at: 0)
        if eventLog.count > 80 {
            eventLog.removeLast(eventLog.count - 80)
        }
    }
}
