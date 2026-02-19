//
//  GmailService.swift
//  FinanceFlow
//
//  Servicio para obtener emails desde Gmail API.
//  Requiere que el usuario haya iniciado sesión con Google y concedido gmail.readonly.
//

import Foundation
import GoogleSignIn

enum GmailServiceError: LocalizedError {
    case notSignedInWithGoogle
    case missingGmailScope
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .notSignedInWithGoogle:
            return "Debes iniciar sesión con Google para importar desde Gmail."
        case .missingGmailScope:
            return "Se necesita permiso para leer correos. Cierra sesión e inicia de nuevo con Google."
        case .apiError(let msg):
            return msg
        }
    }
}

/// Mensaje mínimo de Gmail (id, snippet, internalDate)
struct GmailMessage {
    let id: String
    let snippet: String
    let internalDate: String?
}

@MainActor
final class GmailService {
    static let shared = GmailService()
    private static let gmailScope = "https://www.googleapis.com/auth/gmail.readonly"

    private init() {}

    /// Verifica si el usuario puede usar la importación desde Gmail
    func canImportFromGmail() -> Bool {
        guard let user = GIDSignIn.sharedInstance.currentUser else { return false }
        return user.grantedScopes?.contains(Self.gmailScope) == true
    }

    /// Obtiene el access token actual. Si falta el scope de Gmail, retorna nil.
    private func getAccessToken() async throws -> String {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw GmailServiceError.notSignedInWithGoogle
        }

        if user.grantedScopes?.contains(Self.gmailScope) != true {
            throw GmailServiceError.missingGmailScope
        }

        let refreshedUser = try await user.refreshTokensIfNeeded()
        return refreshedUser.accessToken.tokenString
    }

    /// Lista mensajes con filtros
    /// - Parameters:
    ///   - from: Email remitente (ej. nu@nu.com.co)
    ///   - subject: Palabra/frase en el subject
    ///   - after: Fecha inicio (YYYY/MM/DD)
    ///   - before: Fecha fin (YYYY/MM/DD)
    func fetchMessages(from: String, subject: String, after: String, before: String) async throws -> [GmailMessage] {
        let token = try await getAccessToken()

        let q = "from:\(from) subject:\(subject) after:\(after) before:\(before)"
        let encodedQ = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages?q=\(encodedQ)&maxResults=100")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw GmailServiceError.apiError("Respuesta inválida")
        }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GmailServiceError.apiError("Gmail API: \(http.statusCode) - \(body)")
        }

        struct ListResponse: Decodable {
            let messages: [MessageRef]?
            struct MessageRef: Decodable {
                let id: String
            }
        }

        let list = try JSONDecoder().decode(ListResponse.self, from: data)
        guard let ids = list.messages, !ids.isEmpty else { return [] }

        var results: [GmailMessage] = []
        for ref in ids {
            let msg = try await fetchMessage(id: ref.id, token: token)
            results.append(msg)
        }
        return results
    }

    private func fetchMessage(id: String, token: String) async throws -> GmailMessage {
        let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)?fields=id,snippet,internalDate")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw GmailServiceError.apiError("Error obteniendo mensaje: \(body)")
        }

        struct MessageResponse: Decodable {
            let id: String
            let snippet: String?
            let internalDate: String?
        }

        let decoded = try JSONDecoder().decode(MessageResponse.self, from: data)
        return GmailMessage(
            id: decoded.id,
            snippet: decoded.snippet ?? "",
            internalDate: decoded.internalDate
        )
    }
}
