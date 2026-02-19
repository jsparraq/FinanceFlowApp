//
//  AuthProvider.swift
//  FinanceFlow
//
//  Protocolo común para cualquier método de autenticación (email/contraseña,
//  Google, Apple, etc.). Patrón Factory para extender con nuevos proveedores.
//

import Foundation
import UIKit

/// Resultado de una operación de autenticación
enum AuthResult {
    case success
    case failure(Error)
}

/// Proveedor de autenticación. Cada implementación (email/contraseña, Google, Apple)
/// cumple este protocolo para que AuthService pueda usarlos de forma intercambiable.
protocol AuthProvider: AnyObject {
    /// Identificador del tipo de proveedor (para logs y analytics)
    var providerId: String { get }

    /// Inicia sesión con las credenciales propias del proveedor.
    /// En email/contraseña: email + password. En OAuth: se maneja por URL/callback.
    func signIn(credentials: AuthCredentials) async -> AuthResult

    /// Registra un nuevo usuario (solo aplica a email/contraseña u otros que lo soporten).
    /// Para OAuth puede devolver .failure si no aplica.
    func signUp(credentials: AuthCredentials) async -> AuthResult

    /// Cierra la sesión del usuario actual
    func signOut() async -> AuthResult

    /// Obtiene la sesión actual (async; en Supabase la sesión se lee de forma asíncrona)
    func getSession() async -> AuthSession?

    /// Inicia sesión con OAuth nativo (Google, Apple). Por defecto devuelve .failure.
    /// Solo GoogleAuthProvider y AppleAuthProvider implementan este flujo.
    func signInWithOAuth(from viewController: UIViewController) async -> AuthResult
}

extension AuthProvider {
    func signInWithOAuth(from viewController: UIViewController) async -> AuthResult {
        .failure(AuthError.unsupportedCredentials)
    }
}

/// Credenciales genéricas para no acoplar el protocolo a email/password
enum AuthCredentials {
    case emailPassword(email: String, password: String)
    /// Futuro: Google token, Apple token, etc.
    // case google(idToken: String, accessToken: String)
    // case apple(identityToken: String, authorizationCode: String)
}

/// Sesión de usuario devuelta por cualquier proveedor
struct AuthSession: Sendable {
    let userId: UUID
    let email: String?
    let expiresAt: Date
}
