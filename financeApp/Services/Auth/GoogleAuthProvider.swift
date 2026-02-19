//
//  GoogleAuthProvider.swift
//  FinanceFlow
//
//  Autenticación con Google Sign-In. Obtiene el ID token de Google
//  y lo envía a Supabase para crear/obtener la sesión.
//
//  IMPORTANTE: Añade el URL scheme en Xcode para el callback OAuth:
//  Target → Info → URL Types → + → URL Schemes: com.googleusercontent.apps.TU_CLIENT_ID
//  (invierte tu Client ID: 872965469087-xxx.apps.googleusercontent.com
//   → com.googleusercontent.apps.872965469087-xxx)
//

import Foundation
import Supabase
import GoogleSignIn
import UIKit

final class GoogleAuthProvider: AuthProvider {
    var providerId: String { "google" }

    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientService.shared) {
        self.client = client
        configureGoogleSignIn()
    }

    private func configureGoogleSignIn() {
        guard let clientId = GoogleConfig.clientId else {
            print("[GoogleAuth] GCP_PROJECT_ID_API no configurado en Secrets.plist")
            return
        }
        // serverClientID hace que el idToken tenga la audiencia correcta para que Supabase lo verifique.
        // Usa el mismo GCP_PROJECT_ID_API que debes configurar en Supabase Dashboard → Google.
        let config = GIDConfiguration(clientID: clientId, serverClientID: clientId)
        GIDSignIn.sharedInstance.configuration = config
    }

    func getSession() async -> AuthSession? {
        guard let session = try? await client.auth.session else { return nil }
        return mapSession(session)
    }

    func signIn(credentials: AuthCredentials) async -> AuthResult {
        // Google usa signInWithOAuth(from:) en lugar de credenciales
        .failure(AuthError.unsupportedCredentials)
    }

    func signUp(credentials: AuthCredentials) async -> AuthResult {
        // Con Google no hay "sign up" separado; es el mismo flujo que signIn
        return await signIn(credentials: credentials)
    }

    /// Scopes adicionales para Gmail (importar gastos desde correo)
    private static let gmailScopes = ["https://www.googleapis.com/auth/gmail.readonly"]

    func signInWithOAuth(from viewController: UIViewController) async -> AuthResult {
        guard GoogleConfig.clientId != nil else {
            return .failure(AuthError.missingGoogleConfig)
        }
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: viewController,
                hint: nil,
                additionalScopes: Self.gmailScopes
            )
            guard let idToken = result.user.idToken?.tokenString else {
                return .failure(AuthError.missingIdToken)
            }
            let accessToken = result.user.accessToken.tokenString
            try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken
                )
            )
            return .success
        } catch {
            let nsError = error as NSError
            if nsError.domain == "com.google.GIDSignIn" && nsError.code == -5 {
                return .failure(AuthError.userCanceled)
            }
            return .failure(error)
        }
    }

    func signOut() async -> AuthResult {
        GIDSignIn.sharedInstance.signOut()
        do {
            try await client.auth.signOut()
            return .success
        } catch {
            return .failure(error)
        }
    }

    private func mapSession(_ session: Session) -> AuthSession {
        let expiresAt = Date(timeIntervalSince1970: session.expiresAt)
        return AuthSession(
            userId: session.user.id,
            email: session.user.email,
            expiresAt: expiresAt
        )
    }
}
