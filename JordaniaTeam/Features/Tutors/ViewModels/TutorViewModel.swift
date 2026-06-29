//
//  TutorViewModel.swift
//  JordaniaTeam
//

import Foundation
import OSLog
import Observation
import UIKit

@Observable
@MainActor
final class TutorViewModel {

    private static let logger = Logger(subsystem: "app.jordania", category: "Tutors")

    var name: String = ""
    var username: String = ""
    var isPrivate: Bool = false
    var imgURL: String = ""
    var birthday: String = ""

    var tutorId: UUID?
    var userId: UUID?
    var updatedAt: String?
    var reportsCounter: Int?
    var currentTutor: TutorProfile?

    var errorMessage: String?
    var successMessage: String?
    var lastRequestDebug: String?
    var usersMeStatus: String = "not run"
    var usersMeBody: String = "<empty>"
    var currentUserResponse: CurrentUserResponse?
    var tutorGetStatus: String = "not run"
    var tutorGetBody: String = "<empty>"
    var tutorPutStatus: String = "not run"
    var tutorPutBody: String = "<empty>"
    var profileImageUploadStatus: String = "not run"
    var profileImageUploadBody: String = "<empty>"
    var profileImageDeleteStatus: String = "not run"
    var profileImageDeleteBody: String = "<empty>"
    var profileImageSelectionStatus: String = "none"
    var selectedProfileImage: UIImage?
    var refreshStatus: String = "not run"
    var refreshBody: String = "<empty>"
    var refreshOldAccessToken: String = "<none>"
    var refreshNewAccessToken: String = "<none>"
    var refreshOldRefreshToken: String = "<none>"
    var refreshNewRefreshToken: String = "<none>"
    var negativeTestStatus: String = "not run"
    var negativeTestBody: String = "<empty>"
    var lastRefreshAt: Date?
    var isLoading: Bool = false
    var isSaving: Bool = false
    var isDebugActionRunning: Bool = false
    var isProfileImageActionRunning: Bool = false

    private let maxProfileImageUploadBytes = 5 * 1024 * 1024
    private var selectedProfileImageUploadData: Data?

    var putPreviewJSON: String {
        jsonPreview(
            for: UpsertTutorRequest(
                name: trimmed(name),
                username: trimmed(username),
                isPrivate: isPrivate,
                imgURL: optionalTrimmed(imgURL),
                birthday: optionalTrimmed(birthday)
            )
        )
    }

    var profileImageDisplayURL: URL? {
        guard
            let value = currentTutor?.imgURL,
            !value.isEmpty
        else {
            return nil
        }
        return URL(string: value)
    }

    var profileImageDisplayURLString: String {
        currentTutor?.imgURL ?? "null"
    }

    var canUploadSelectedProfileImage: Bool {
        selectedProfileImageUploadData != nil && !isProfileImageActionRunning
    }

    private let session: SessionStore
    private let service: TutorsService
    private let debugService: DebugAPIService
    private let birthdayInputFormatter: DateFormatter
    private let birthdayOutputFormatter: DateFormatter

    init(
        session: SessionStore,
        service: TutorsService,
        debugService: DebugAPIService
    ) {
        self.session = session
        self.service = service
        self.debugService = debugService
        self.birthdayInputFormatter = DateFormatter()
        self.birthdayInputFormatter.calendar = Calendar(identifier: .gregorian)
        self.birthdayInputFormatter.locale = Locale(identifier: "pt_BR")
        self.birthdayInputFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        self.birthdayInputFormatter.dateFormat = "dd/MM/yyyy"
        self.birthdayInputFormatter.isLenient = false

        self.birthdayOutputFormatter = DateFormatter()
        self.birthdayOutputFormatter.calendar = Calendar(identifier: .gregorian)
        self.birthdayOutputFormatter.locale = Locale(identifier: "en_US_POSIX")
        self.birthdayOutputFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        self.birthdayOutputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        self.birthdayOutputFormatter.isLenient = false
    }

    func loadTutor() async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        lastRequestDebug = "GET /api/tutors/me\nbody: <empty>"

        do {
            let result = try await service.fetchMeDebug()
            tutorGetStatus = "HTTP \(result.statusCode)"
            tutorGetBody = bodyText(result.body)
            if let tutor = result.value {
                apply(tutor)
            } else {
                resetForNewTutor()
                if result.statusCode == 404 {
                    successMessage = "GET /api/tutors/me -> 404: tutor ainda não criado."
                } else if !(200...299).contains(result.statusCode) {
                    errorMessage = "GET /api/tutors/me -> HTTP \(result.statusCode)"
                }
            }
        } catch let error as HTTPStatusError {
            Self.logger.error("fetchMe falhou: \(error.debugMessage, privacy: .public)")
            errorMessage = error.debugMessage
        } catch let error as NetworkError {
            Self.logger.error("fetchMe falhou: \(error)")
            errorMessage = tutorMessage(for: error, operation: "GET /api/tutors/me")
        } catch {
            Self.logger.error("fetchMe erro inesperado: \(error)")
            errorMessage = "Não foi possível carregar o tutor."
        }

        isLoading = false
    }

    func loadCurrentUser() async {
        isDebugActionRunning = true
        errorMessage = nil
        successMessage = nil

        do {
            let result = try await debugService.fetchCurrentUserDebug()
            usersMeStatus = "HTTP \(result.statusCode)"
            usersMeBody = bodyText(result.body)
            currentUserResponse = result.value
            if let value = result.value {
                successMessage = "/users/me carregado: \(value.id.uuidString)"
            } else {
                errorMessage = "/users/me -> HTTP \(result.statusCode)"
            }
        } catch {
            usersMeStatus = "error"
            usersMeBody = String(describing: error)
            errorMessage = "Falha em /users/me: \(String(describing: error))"
        }

        session.refreshDebugSnapshot()
        isDebugActionRunning = false
    }

    func saveTutor() async {
        let trimmedName = trimmed(name)
        let trimmedUsername = trimmed(username)

        guard !trimmedName.isEmpty, !trimmedUsername.isEmpty else {
            errorMessage = "Preencha name e username."
            successMessage = nil
            return
        }

        isSaving = true
        errorMessage = nil
        successMessage = nil

        let normalizedImgURL: String?
        let normalizedBirthday: String?
        do {
            normalizedImgURL = try normalizeImageURL(imgURL)
            normalizedBirthday = try normalizeBirthday(birthday)
        } catch {
            isSaving = false
            successMessage = nil
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Campos inválidos."
            return
        }

        imgURL = normalizedImgURL ?? ""
        birthday = normalizedBirthday ?? ""

        let request = UpsertTutorRequest(
            name: trimmedName,
            username: trimmedUsername,
            isPrivate: isPrivate,
            imgURL: normalizedImgURL,
            birthday: normalizedBirthday
        )
        lastRequestDebug = "PUT /api/tutors/me\nbody:\n\(jsonPreview(for: request))"

        do {
            let result = try await service.upsertMeDebug(request)
            tutorPutStatus = "HTTP \(result.statusCode)"
            tutorPutBody = bodyText(result.body)
            if let tutor = result.value {
                apply(tutor)
                successMessage = "Tutor salvo."
            } else {
                errorMessage = "PUT /api/tutors/me -> HTTP \(result.statusCode)"
            }
        } catch let error as TutorsServiceError {
            Self.logger.error("upsertMe falhou: \(error)")
            errorMessage = error.errorDescription
        } catch let error as HTTPStatusError {
            Self.logger.error("upsertMe falhou: \(error.debugMessage, privacy: .public)")
            errorMessage = error.debugMessage
        } catch let error as NetworkError {
            Self.logger.error("upsertMe falhou: \(error)")
            errorMessage = tutorMessage(for: error, operation: "PUT /api/tutors/me")
        } catch {
            Self.logger.error("upsertMe erro inesperado: \(error)")
            errorMessage = "Não foi possível salvar o tutor."
        }

        isSaving = false
    }

    func prepareSelectedProfileImage(data: Data) {
        errorMessage = nil
        successMessage = nil

        guard let image = UIImage(data: data) else {
            selectedProfileImage = nil
            selectedProfileImageUploadData = nil
            profileImageSelectionStatus = "invalid image data"
            errorMessage = "Não foi possível ler a imagem selecionada."
            return
        }

        guard let uploadData = jpegDataForUpload(from: image) else {
            selectedProfileImage = nil
            selectedProfileImageUploadData = nil
            profileImageSelectionStatus = "could not encode JPEG"
            errorMessage = "Não foi possível preparar a imagem para upload."
            return
        }

        guard uploadData.count <= maxProfileImageUploadBytes else {
            selectedProfileImage = nil
            selectedProfileImageUploadData = nil
            profileImageSelectionStatus = "\(formattedByteCount(uploadData.count)) > 5 MB"
            errorMessage = "A imagem ficou maior que 5 MB mesmo após compressão."
            return
        }

        selectedProfileImage = UIImage(data: uploadData)
        selectedProfileImageUploadData = uploadData
        profileImageSelectionStatus = "JPEG \(formattedByteCount(uploadData.count))"
    }

    func clearSelectedProfileImage() {
        selectedProfileImage = nil
        selectedProfileImageUploadData = nil
        profileImageSelectionStatus = "none"
    }

    func failProfileImageSelection(_ error: Error) {
        selectedProfileImage = nil
        selectedProfileImageUploadData = nil
        profileImageSelectionStatus = "selection error"
        errorMessage = "Falha ao carregar imagem selecionada: \(String(describing: error))"
        successMessage = nil
    }

    func uploadSelectedProfileImage() async {
        guard let imageData = selectedProfileImageUploadData else {
            errorMessage = "Selecione uma imagem antes de fazer upload."
            successMessage = nil
            return
        }

        isProfileImageActionRunning = true
        errorMessage = nil
        successMessage = nil
        lastRequestDebug = """
        POST /api/tutors/me/profile-image
        body: multipart/form-data; field=file; filename=profile-image.jpg; bytes=\(imageData.count)
        """

        do {
            let result = try await service.uploadProfileImageDebug(
                imageData: imageData,
                filename: "profile-image.jpg",
                mimeType: "image/jpeg"
            )
            profileImageUploadStatus = "HTTP \(result.statusCode)"
            profileImageUploadBody = bodyText(result.body)
            if let tutor = result.value {
                apply(tutor)
                successMessage = "Foto de perfil enviada."
            } else {
                errorMessage = "POST /api/tutors/me/profile-image -> HTTP \(result.statusCode)"
            }
        } catch let error as HTTPStatusError {
            Self.logger.error("uploadProfileImage falhou: \(error.debugMessage, privacy: .public)")
            profileImageUploadStatus = "error"
            profileImageUploadBody = error.debugMessage
            errorMessage = error.debugMessage
        } catch let error as NetworkError {
            Self.logger.error("uploadProfileImage falhou: \(error)")
            profileImageUploadStatus = "error"
            profileImageUploadBody = String(describing: error)
            errorMessage = tutorMessage(for: error, operation: "POST /api/tutors/me/profile-image")
        } catch {
            Self.logger.error("uploadProfileImage erro inesperado: \(error)")
            profileImageUploadStatus = "error"
            profileImageUploadBody = String(describing: error)
            errorMessage = "Não foi possível enviar a foto de perfil."
        }

        isProfileImageActionRunning = false
    }

    func deleteProfileImage() async {
        isProfileImageActionRunning = true
        errorMessage = nil
        successMessage = nil
        lastRequestDebug = "DELETE /api/tutors/me/profile-image\nbody: <empty>"

        do {
            let result = try await service.deleteProfileImageDebug()
            profileImageDeleteStatus = "HTTP \(result.statusCode)"
            profileImageDeleteBody = bodyText(result.body)
            if let tutor = result.value {
                apply(tutor)
                successMessage = "Foto de perfil removida."
            } else {
                errorMessage = "DELETE /api/tutors/me/profile-image -> HTTP \(result.statusCode)"
            }
        } catch let error as HTTPStatusError {
            Self.logger.error("deleteProfileImage falhou: \(error.debugMessage, privacy: .public)")
            profileImageDeleteStatus = "error"
            profileImageDeleteBody = error.debugMessage
            errorMessage = error.debugMessage
        } catch let error as NetworkError {
            Self.logger.error("deleteProfileImage falhou: \(error)")
            profileImageDeleteStatus = "error"
            profileImageDeleteBody = String(describing: error)
            errorMessage = tutorMessage(for: error, operation: "DELETE /api/tutors/me/profile-image")
        } catch {
            Self.logger.error("deleteProfileImage erro inesperado: \(error)")
            profileImageDeleteStatus = "error"
            profileImageDeleteBody = String(describing: error)
            errorMessage = "Não foi possível remover a foto de perfil."
        }

        isProfileImageActionRunning = false
    }

    func forceRefresh() async {
        isDebugActionRunning = true
        errorMessage = nil
        successMessage = nil

        guard let credentials = session.loadCredentials() else {
            refreshStatus = "missing credentials"
            refreshBody = "Keychain não tem SessionCredentials."
            errorMessage = refreshBody
            isDebugActionRunning = false
            return
        }

        refreshOldAccessToken = credentials.maskedAccessToken
        refreshOldRefreshToken = credentials.maskedRefreshToken

        do {
            let authSession = try await debugService.forceRefresh(refreshToken: credentials.refreshToken)
            try session.replaceSession(
                user: authSession.user,
                credentials: authSession.credentials,
                event: "manual refresh: \(credentials.maskedRefreshToken) -> \(authSession.credentials.maskedRefreshToken)"
            )
            refreshNewAccessToken = authSession.credentials.maskedAccessToken
            refreshNewRefreshToken = authSession.credentials.maskedRefreshToken
            refreshStatus = "HTTP 200"
            refreshBody = "Novo access e refresh salvos no Keychain."
            lastRefreshAt = Date()
            successMessage = "Refresh manual concluído."
        } catch {
            refreshStatus = "error"
            refreshBody = String(describing: error)
            errorMessage = "Refresh manual falhou: \(String(describing: error))"
        }

        session.refreshDebugSnapshot()
        isDebugActionRunning = false
    }

    func testInvalidRefresh() async {
        isDebugActionRunning = true
        errorMessage = nil
        successMessage = nil

        do {
            let result = try await debugService.refreshDebug(refreshToken: "invalid-\(UUID().uuidString)")
            negativeTestStatus = "POST /auth/refresh invalid -> HTTP \(result.statusCode)"
            negativeTestBody = bodyText(result.body)
            successMessage = "Teste negativo de refresh executado."
        } catch {
            negativeTestStatus = "POST /auth/refresh invalid -> error"
            negativeTestBody = String(describing: error)
            errorMessage = "Teste negativo falhou por transporte: \(String(describing: error))"
        }

        isDebugActionRunning = false
    }

    func testUsersMeWithoutToken() async {
        isDebugActionRunning = true
        errorMessage = nil
        successMessage = nil

        do {
            let result = try await debugService.usersMeWithoutToken()
            negativeTestStatus = "GET /users/me sem token -> HTTP \(result.statusCode)"
            negativeTestBody = bodyText(result.body)
            successMessage = "Teste sem token executado."
        } catch {
            negativeTestStatus = "GET /users/me sem token -> error"
            negativeTestBody = String(describing: error)
            errorMessage = "Teste sem token falhou por transporte: \(String(describing: error))"
        }

        isDebugActionRunning = false
    }

    func clearLocalSession() {
        session.recordAuthEvent("debug: local session cleared from dashboard")
        session.signOut()
    }

    private func apply(_ tutor: TutorProfile) {
        currentTutor = tutor
        tutorId = tutor.id
        userId = tutor.userId
        name = tutor.name
        username = tutor.username
        isPrivate = tutor.isPrivate
        imgURL = ""
        birthday = tutor.birthday ?? ""
        updatedAt = tutor.updatedAt
        reportsCounter = tutor.reportsCounter
    }

    private func resetForNewTutor() {
        currentTutor = nil
        tutorId = nil
        userId = nil
        name = ""
        username = ""
        isPrivate = false
        imgURL = ""
        birthday = ""
        updatedAt = nil
        reportsCounter = nil
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func optionalTrimmed(_ value: String) -> String? {
        let value = trimmed(value)
        return value.isEmpty ? nil : value
    }

    private func normalizeImageURL(_ value: String) throws -> String? {
        guard var value = optionalTrimmed(value) else { return nil }
        if !value.contains("://") {
            value = "https://\(value)"
        }

        guard
            let components = URLComponents(string: value),
            let scheme = components.scheme?.lowercased(),
            ["http", "https"].contains(scheme),
            components.host?.isEmpty == false
        else {
            throw TutorFormValidationError.invalidImageURL
        }

        return value
    }

    private func normalizeBirthday(_ value: String) throws -> String? {
        guard let value = optionalTrimmed(value) else { return nil }

        if value.range(
            of: #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$"#,
            options: .regularExpression
        ) != nil {
            return value
        }

        if value.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
            return "\(value)T00:00:00"
        }

        if let date = birthdayInputFormatter.date(from: value) {
            return birthdayOutputFormatter.string(from: date)
        }

        throw TutorFormValidationError.invalidBirthday
    }

    private func jpegDataForUpload(from image: UIImage) -> Data? {
        let image = resizedImageForUpload(image)
        let qualities: [CGFloat] = [0.9, 0.8, 0.7, 0.6, 0.5]

        var smallestData: Data?
        for quality in qualities {
            guard let data = image.jpegData(compressionQuality: quality) else { continue }
            smallestData = data
            if data.count <= maxProfileImageUploadBytes {
                return data
            }
        }

        return smallestData
    }

    private func resizedImageForUpload(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 1_600
        let size = image.size
        guard size.width > 0, size.height > 0 else {
            return image
        }

        let largestDimension = max(size.width, size.height)
        let scale = min(1, maxDimension / largestDimension)
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let bounds = CGRect(origin: .zero, size: targetSize)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { context in
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fill(bounds)
            image.draw(in: bounds)
        }
    }

    private func jsonPreview(for request: UpsertTutorRequest) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard
            let data = try? encoder.encode(request),
            let json = String(data: data, encoding: .utf8)
        else {
            return "<falha ao montar preview JSON>"
        }
        return json
    }

    private func bodyText(_ body: String?) -> String {
        guard let body, !body.isEmpty else { return "<empty>" }
        return body
    }

    private func formattedByteCount(_ count: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }

    private func tutorMessage(for error: NetworkError, operation: String) -> String {
        switch error {
        case .serverError(let statusCode):
            return "\(operation) -> HTTP \(statusCode)"
        default:
            return error.errorDescription ?? "Falha em \(operation)."
        }
    }
}

private enum TutorFormValidationError: LocalizedError {
    case invalidImageURL
    case invalidBirthday

    var errorDescription: String? {
        switch self {
        case .invalidImageURL:
            return "img_url inválido. Use uma URL com domínio, por exemplo https://example.com/avatar.png."
        case .invalidBirthday:
            return "birthday inválido. Use 2003-10-31T00:00:00, 2003-10-31 ou 31/10/2003."
        }
    }
}
