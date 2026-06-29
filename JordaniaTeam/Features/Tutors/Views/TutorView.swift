//
//  TutorView.swift
//  JordaniaTeam
//

import SwiftUI

struct TutorView: View {

    @State private var viewModel: TutorViewModel
    private let session: SessionStore
    private let onSignOut: () -> Void

    init(session: SessionStore, apiClient: APIClient, onSignOut: @escaping () -> Void) {
        _viewModel = State(
            initialValue: TutorViewModel(
                session: session,
                service: TutorsService(apiClient: apiClient),
                debugService: DebugAPIService(apiClient: apiClient)
            )
        )
        self.session = session
        self.onSignOut = onSignOut
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    environmentPanel
                    sessionDebugPanel
                    accessTokenPanel
                    refreshTokenPanel
                    usersMePanel
                    tutorForm
                    tutorMetadata
                    requestDebugPanel
                    refreshDebugPanel
                    negativeTestsPanel
                    eventLogPanel
                    messagePanel
                }
                .padding()
            }
            .navigationTitle("Auth Debug POC")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Reload all") {
                        Task {
                            await viewModel.loadCurrentUser()
                            await viewModel.loadTutor()
                        }
                    }
                    .disabled(viewModel.isLoading || viewModel.isSaving || viewModel.isDebugActionRunning)

                    Button("Sign Out", role: .destructive, action: onSignOut)
                }
            }
            .task {
                await viewModel.loadCurrentUser()
                await viewModel.loadTutor()
            }
        }
    }

    private var environmentPanel: some View {
        DebugPanel(title: "Environment") {
            DebugRow(label: "baseURL", value: AppConfiguration.apiBaseURL.absoluteString)
            DebugRow(label: "local time", value: Self.dateTimeFormatter.string(from: Date()))
            DebugRow(label: "bundle", value: Bundle.main.bundleIdentifier ?? "unknown")
            DebugRow(label: "build", value: buildDescription)
        }
    }

    private var sessionDebugPanel: some View {
        DebugPanel(title: "Session") {
            if let user = session.currentUser {
                DebugRow(label: "userId", value: user.id.uuidString)
                DebugRow(label: "name local", value: user.name ?? "null")
                DebugRow(label: "email", value: user.email ?? "null")
                DebugRow(label: "provider", value: user.provider.rawValue)
                DebugRow(label: "role", value: user.role.rawValue)
            } else {
                DebugRow(label: "session", value: "ausente")
            }
            DebugRow(label: "credentials", value: session.debugSnapshot.hasCredentials ? "presente" : "ausente")
            DebugRow(label: "legacy token", value: session.debugSnapshot.hasLegacyAccessToken ? "presente" : "ausente")
            DebugRow(label: "last auth", value: session.lastAuthEvent ?? "null")
            DebugRow(label: "last logout", value: session.lastLogoutStatus ?? "null")
        }
    }

    private var accessTokenPanel: some View {
        DebugPanel(title: "Access token claims") {
            DebugRow(label: "token", value: session.debugSnapshot.accessTokenMasked ?? "ausente")
            if let claims = session.debugSnapshot.accessClaims {
                DebugRow(label: "sub", value: claims.subject ?? "null")
                DebugRow(label: "iss", value: claims.issuer ?? "null")
                DebugRow(label: "iat", value: format(claims.issuedAt))
                DebugRow(label: "exp", value: format(claims.expiresAt))
                DebugRow(label: "expires in", value: seconds(claims.expiresIn))
                DebugRow(label: "provider", value: claims.provider ?? "null")
                DebugRow(label: "role", value: claims.role ?? "null")
                DebugRow(label: "email", value: claims.email ?? "null")
                DebugRow(label: "name", value: claims.name ?? "null")
            } else {
                DebugRow(label: "claims", value: "null")
            }
        }
    }

    private var refreshTokenPanel: some View {
        DebugPanel(title: "Refresh token") {
            DebugRow(label: "token", value: session.debugSnapshot.refreshTokenMasked ?? "ausente")
            DebugRow(label: "expires at", value: format(session.debugSnapshot.refreshExpiresAt))
            if let refreshExpiresAt = session.debugSnapshot.refreshExpiresAt {
                DebugRow(label: "expires in", value: seconds(refreshExpiresAt.timeIntervalSinceNow))
            } else {
                DebugRow(label: "expires in", value: "null")
            }
        }
    }

    private var usersMePanel: some View {
        DebugPanel(title: "/users/me") {
            HStack {
                Button("Load /users/me") {
                    Task { await viewModel.loadCurrentUser() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isDebugActionRunning)

                Text(viewModel.usersMeStatus)
                    .font(.caption.monospaced())
            }

            if let current = viewModel.currentUserResponse {
                DebugRow(label: "id", value: current.id.uuidString)
                DebugRow(label: "email", value: current.email ?? "null")
                DebugRow(label: "provider", value: current.provider.rawValue)
                DebugRow(label: "role", value: current.role.rawValue)
                DebugRow(label: "name", value: current.name ?? "null")
            }

            DebugBlock(title: "raw body", value: viewModel.usersMeBody)
        }
    }

    private var tutorForm: some View {
        DebugPanel(title: "PUT /api/tutors/me") {
            TextField("name", text: $viewModel.name)
                .textFieldStyle(.roundedBorder)

            TextField("username", text: $viewModel.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            Toggle("is_private", isOn: $viewModel.isPrivate)

            TextField("img_url", text: $viewModel.imgURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .textFieldStyle(.roundedBorder)
            Text("https://example.com/avatar.png")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("birthday", text: $viewModel.birthday)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
            Text("2003-10-31T00:00:00, 2003-10-31 ou 31/10/2003")
                .font(.caption)
                .foregroundStyle(.secondary)

            DebugBlock(title: "preview JSON", value: viewModel.putPreviewJSON)

            Button {
                Task { await viewModel.saveTutor() }
            } label: {
                if viewModel.isSaving {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading || viewModel.isSaving)

            DebugRow(label: "last PUT", value: viewModel.tutorPutStatus)
            DebugBlock(title: "PUT raw body", value: viewModel.tutorPutBody)
        }
    }

    private var tutorMetadata: some View {
        DebugPanel(title: "Tutor data") {
            if let tutor = viewModel.currentTutor {
                DebugRow(label: "id", value: tutor.id.uuidString)
                DebugRow(label: "user_id", value: tutor.userId.uuidString)
                DebugRow(label: "name", value: tutor.name)
                DebugRow(label: "username", value: tutor.username)
                DebugRow(label: "is_private", value: String(tutor.isPrivate))
                DebugRow(label: "img_url", value: tutor.imgURL ?? "null")
                DebugRow(label: "birthday", value: tutor.birthday ?? "null")
                DebugRow(label: "updated_at", value: tutor.updatedAt)
                DebugRow(label: "reports_counter", value: String(tutor.reportsCounter))
            } else {
                DebugRow(label: "id", value: "null")
                DebugRow(label: "user_id", value: "null")
                DebugRow(label: "name", value: "null")
                DebugRow(label: "username", value: "null")
                DebugRow(label: "is_private", value: "null")
                DebugRow(label: "img_url", value: "null")
                DebugRow(label: "birthday", value: "null")
                DebugRow(label: "updated_at", value: "null")
                DebugRow(label: "reports_counter", value: "null")
            }
        }
    }

    private var requestDebugPanel: some View {
        DebugPanel(title: "GET /api/tutors/me") {
            HStack {
                Button("GET tutor") {
                    Task { await viewModel.loadTutor() }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading)

                Text(viewModel.tutorGetStatus)
                    .font(.caption.monospaced())
            }

            DebugBlock(title: "last request", value: viewModel.lastRequestDebug ?? "<none>")
            DebugBlock(title: "GET raw body", value: viewModel.tutorGetBody)
        }
    }

    private var refreshDebugPanel: some View {
        DebugPanel(title: "Refresh") {
            Button("Force refresh") {
                Task { await viewModel.forceRefresh() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isDebugActionRunning)

            DebugRow(label: "status", value: viewModel.refreshStatus)
            DebugRow(label: "at", value: format(viewModel.lastRefreshAt))
            DebugRow(label: "old access", value: viewModel.refreshOldAccessToken)
            DebugRow(label: "new access", value: viewModel.refreshNewAccessToken)
            DebugRow(label: "old refresh", value: viewModel.refreshOldRefreshToken)
            DebugRow(label: "new refresh", value: viewModel.refreshNewRefreshToken)
            DebugBlock(title: "body", value: viewModel.refreshBody)
        }
    }

    private var negativeTestsPanel: some View {
        DebugPanel(title: "Negative tests") {
            HStack {
                Button("Invalid refresh") {
                    Task { await viewModel.testInvalidRefresh() }
                }
                .buttonStyle(.bordered)

                Button("/users/me no token") {
                    Task { await viewModel.testUsersMeWithoutToken() }
                }
                .buttonStyle(.bordered)
            }
            .disabled(viewModel.isDebugActionRunning)

            Button("Clear local session", role: .destructive) {
                viewModel.clearLocalSession()
            }
            .buttonStyle(.bordered)

            DebugRow(label: "status", value: viewModel.negativeTestStatus)
            DebugBlock(title: "body", value: viewModel.negativeTestBody)
        }
    }

    private var eventLogPanel: some View {
        DebugPanel(title: "Event log") {
            if session.eventLog.isEmpty {
                Text("<empty>")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            } else {
                ForEach(session.eventLog.prefix(30)) { event in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Self.timeFormatter.string(from: event.date))
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                        Text(event.message)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Divider()
                }
            }
        }
    }

    @ViewBuilder
    private var messagePanel: some View {
        if viewModel.isLoading {
            ProgressView("Loading...")
        }

        if let error = viewModel.errorMessage {
            Text(error)
                .foregroundStyle(.red)
                .font(.footnote)
                .textSelection(.enabled)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }

        if let success = viewModel.successMessage {
            Text(success)
                .foregroundStyle(.green)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private var buildDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        if let version, let build {
            return "\(version) (\(build))"
        }
        return version ?? build ?? "unknown"
    }

    private func format(_ date: Date?) -> String {
        guard let date else { return "null" }
        return Self.dateTimeFormatter.string(from: date)
    }

    private func seconds(_ interval: TimeInterval?) -> String {
        guard let interval else { return "null" }
        return "\(Int(interval))s"
    }

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

private struct DebugPanel<Content: View>: View {

    let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct DebugBlock: View {

    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DebugRow: View {

    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 116, alignment: .leading)

            Text(value)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
