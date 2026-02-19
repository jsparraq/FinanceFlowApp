//
//  AuthProviderFactory.swift
//  FinanceFlow
//
//  Factory que devuelve el proveedor de autenticación adecuado.
//  Para añadir Google o Apple: crear GoogleAuthProvider/AppleAuthProvider
//  y devolverlos aquí según el método elegido por el usuario.
//

import Foundation

/// Tipo de autenticación soportado (extensible)
enum AuthMethod: String, CaseIterable {
    case emailPassword = "email_password"
    case google = "google"
    case apple = "apple"
}

/// Crea el proveedor de autenticación según el método.
/// Centraliza la decisión para que la app use un solo punto de configuración.
enum AuthProviderFactory {
    /// Devuelve el proveedor para el método dado.
    /// Por ahora solo email/contraseña está implementado.
    static func makeProvider(for method: AuthMethod) -> AuthProvider {
        switch method {
        case .emailPassword:
            return EmailPasswordAuthProvider()
        case .google:
            return GoogleAuthProvider()
        case .apple:
            return AppleAuthProvider()
        }
    }

    /// Proveedor por defecto (login con correo y contraseña)
    static var defaultProvider: AuthProvider {
        makeProvider(for: .emailPassword)
    }
}
