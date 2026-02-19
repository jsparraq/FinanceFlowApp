//
//  EmailPasswordAuthProvider.swift
//  FinanceFlow
//
//  Autenticación por correo y contraseña usando Supabase Auth.
//  Las contraseñas se envían por HTTPS y Supabase las hashea (bcrypt) en el servidor;
//  nadie con acceso a la BD puede ver la contraseña en texto plano.
//

import Foundation
import Supabase

final class EmailPasswordAuthProvider: AuthProvider {
    var providerId: String { "email_password" }

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientService.shared) {
        self.client = client
    }

    func getSession() async -> AuthSession? {
        guard let session = try? await client.auth.session else { return nil }
        return mapSession(session)
    }

    func signIn(credentials: AuthCredentials) async -> AuthResult {
        guard case .emailPassword(let email, let password) = credentials else {
            return .failure(AuthError.unsupportedCredentials)
        }
        do {
            _ = try await client.auth.signIn(email: email, password: password)
            return .success
        } catch {
            return .failure(error)
        }
    }

    func signUp(credentials: AuthCredentials) async -> AuthResult {
        guard case .emailPassword(let email, let password) = credentials else {
            return .failure(AuthError.unsupportedCredentials)
        }
        do {
            _ = try await client.auth.signUp(email: email, password: password)
            return .success
        } catch {
            return .failure(error)
        }
    }

    func signOut() async -> AuthResult {
        do {
            try await client.auth.signOut()
            return .success
        } catch {
            return .failure(error)
        }
    }

    private func mapSession(_ session: Session) -> AuthSession {
        let expiresAt: Date = {
            let interval = session.expiresAt
            return Date(timeIntervalSince1970: interval)
        }()
        return AuthSession(
            userId: session.user.id,
            email: session.user.email,
            expiresAt: expiresAt
        )
    }
}

/// Errores de autenticación
enum AuthError: LocalizedError {
    case unsupportedCredentials
    case noSession
    case missingGoogleConfig
    case missingIdToken
    case userCanceled

    var errorDescription: String? {
        switch self {
        case .unsupportedCredentials: return "Credenciales no soportadas para este proveedor."
        case .noSession: return "No hay sesión activa."
        case .missingGoogleConfig: return "Google Sign-In no configurado. Añade GCP_PROJECT_ID_API en Secrets.plist."
        case .missingIdToken: return "No se pudo obtener el token de Google."
        case .userCanceled: return "Inicio de sesión cancelado."
        }
    }
}
