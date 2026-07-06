//
//  CertificatePinningDelegate.swift
//  JordaniaTeam
//
//  Created by Gabriel Ferrari on 06/07/26.
//

import Foundation
import CryptoKit
import OSLog

/// Implementa certificate pinning via hash SHA-256 da chave pública (SPKI).
///
/// ## Por que SPKI e não o certificado completo?
/// Pinar o certificado inteiro exige um novo build a cada renovação (e.g. Let's Encrypt a cada 90 dias).
/// Pinar a chave pública permite renovar o certificado mantendo a mesma chave privada — rotação
/// sem breaking change no app. É o padrão recomendado pelo OWASP Mobile Security Testing Guide.
///
/// ## Configuração obrigatória antes do deploy
/// Os hashes placeholder em `AppContainer` devem ser substituídos pelos valores reais.
/// Para extrair o hash do servidor de produção:
/// ```bash
/// openssl s_client -connect api.jordania.app:443 -servername api.jordania.app 2>/dev/null \
///   | openssl x509 -pubkey -noout \
///   | openssl pkey -pubin -outform DER \
///   | openssl dgst -sha256 -binary \
///   | base64
/// ```
///
/// ## Estratégia de rotação
/// Inclua sempre pelo menos dois hashes: o ativo e o backup (chave futura já gerada,
/// certificado ainda não deployado). Faça o release do novo hash *antes* de rotacionar
/// o certificado no servidor.
final class CertificatePinningDelegate: NSObject, URLSessionDelegate {

    private static let logger = Logger(subsystem: "app.jordania", category: "CertificatePinning")

    /// Conjunto de SPKI SHA-256 hashes aceitos, em Base64.
    /// Mínimo recomendado: 2 (ativo + backup).
    private let pinnedHashes: Set<String>

    init(pinnedHashes: Set<String>) {
        precondition(!pinnedHashes.isEmpty, "CertificatePinningDelegate requer ao menos um hash.")
        self.pinnedHashes = pinnedHashes
    }

    // MARK: - URLSessionDelegate

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Apenas trata desafios de confiança de servidor TLS.
        // Outros tipos de desafio (e.g. autenticação HTTP) seguem o fluxo padrão.
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Passo 1: valida a cadeia de certificação completa via SecTrust.
        // O pinning NÃO substitui a validação da CA — é uma camada adicional.
        var trustError: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &trustError) else {
            Self.logger.error("Cadeia TLS inválida — desafio cancelado.")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Passo 2: extrai o certificado folha (índice 0 = mais próximo do servidor).
        guard
            let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0),
            let publicKey = SecCertificateCopyKey(certificate),
            let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?
        else {
            Self.logger.error("Não foi possível extrair a chave pública do certificado folha.")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Passo 3: compara o hash SHA-256 da chave pública com os hashes aceitos.
        let receivedHash = sha256Base64(of: publicKeyData)

        if pinnedHashes.contains(receivedHash) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            // Não loga o hash recebido — evita vazar informação sobre o certificado em logs.
            Self.logger.error("Certificate pinning falhou: hash da chave pública não reconhecido.")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    // MARK: - Private

    private func sha256Base64(of data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return Data(digest).base64EncodedString()
    }
}
