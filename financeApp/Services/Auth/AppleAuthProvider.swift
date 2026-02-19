//
//  AppleAuthProvider.swift
//  FinanceFlow
//
//  Placeholder para futura autenticación con Sign in with Apple.
//  Implementar cuando se integre AuthenticationServices y Supabase Auth con Apple.
//

import Foundation

final class AppleAuthProvider: AuthProvider {
    var providerId: String { "apple" }

    func getSession() async -> AuthSession? {
        // TODO: cuando se integre Apple, devolver sesión si existe
        nil
    }

    func signIn(credentials: AuthCredentials) async -> AuthResult {
        // TODO: solicitar credenciales de Apple (ASAuthorizationAppleIDProvider)
        // y luego client.auth.signInWithIdToken(provider: .apple, ...)
        .failure(AuthError.unsupportedCredentials)
    }

    func signUp(credentials: AuthCredentials) async -> AuthResult {
        // Con Apple es el mismo flujo que signIn
        return await signIn(credentials: credentials)
    }

    func signOut() async -> AuthResult {
        // TODO: cerrar sesión en Supabase (Apple no tiene signOut en dispositivo)
        .failure(AuthError.unsupportedCredentials)
    }
}
