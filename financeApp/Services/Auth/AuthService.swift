//
//  AuthService.swift
//  FinanceFlow
//
//  Servicio de autenticación que usa AuthProviderFactory para obtener el proveedor
//  activo (email/contraseña, Google, Apple). Observa el estado de sesión.
//

import Foundation
import Supabase
import UIKit

@MainActor
@Observable
final class AuthService {
    /// Sesión actual; nil si no hay usuario autenticado
    private(set) var session: AuthSession?

    /// Incrementa al cambiar la sesión (signOut/signIn/refresh); fuerza actualización de la UI.
    private(set) var sessionVersion: Int = 0

    /// Proveedor activo (por defecto email/contraseña; cambiar según método de login)
    private var provider: AuthProvider

    private let client = SupabaseClientService.shared

    var isAuthenticated: Bool { session != nil }

    init(provider: AuthProvider) {
        self.provider = provider
        self.session = nil
    }

    /// Inicia sesión con el proveedor actual
    func signIn(email: String, password: String) async throws {
        let result = await provider.signIn(credentials: .emailPassword(email: email, password: password))
        switch result {
        case .success:
            session = await provider.getSession()
            sessionVersion += 1
            if let s = session {
                print("[Auth] Usuario autenticado: \(s.email ?? "sin email") (userId: \(s.userId))")
            }
        case .failure(let error):
            throw error
        }
    }

    /// Registra un nuevo usuario (email/contraseña)
    func signUp(email: String, password: String) async throws {
        let result = await provider.signUp(credentials: .emailPassword(email: email, password: password))
        switch result {
        case .success:
            session = await provider.getSession()
            sessionVersion += 1
            if let s = session {
                print("[Auth] Usuario autenticado (signUp): \(s.email ?? "sin email") (userId: \(s.userId))")
            }
        case .failure(let error):
            throw error
        }
    }

    /// Cierra la sesión. Siempre limpia `session` local para que la UI actualice;
    /// si falla el signOut en el servidor, aun así se cierra la sesión local.
    func signOut() async throws {
        let result = await provider.signOut()
        switch result {
        case .success:
            session = nil
            sessionVersion += 1
            print("[Auth] signOut: sesión cerrada correctamente")
            NotificationCenter.default.post(name: .authDidSignOut, object: nil)
        case .failure(let error):
            print("[Auth] signOut: error en servidor: \(error.localizedDescription)")
            session = nil
            sessionVersion += 1
            NotificationCenter.default.post(name: .authDidSignOut, object: nil)
            throw error
        }
    }

    /// Refresca el estado de sesión desde el proveedor (p. ej. al volver a primer plano).
    /// Supabase persiste la sesión en el dispositivo; si hay una guardada, aparecerás autenticado al abrir la app.
    func refreshSession() async {
        session = await provider.getSession()
        sessionVersion += 1
        if let s = session {
            print("[Auth] Usuario autenticado (refreshSession): \(s.email ?? "sin email") (userId: \(s.userId))")
        }
    }

    /// Cambia el proveedor (p. ej. para "Iniciar con Google" en la misma pantalla)
    func useProvider(for method: AuthMethod) async {
        provider = AuthProviderFactory.makeProvider(for: method)
        session = await provider.getSession()
        sessionVersion += 1
    }

    /// Inicia sesión con Google (OAuth nativo). Requiere el view controller para presentar el flujo.
    func signInWithGoogle(from viewController: UIViewController) async throws {
        let googleProvider = AuthProviderFactory.makeProvider(for: .google)
        let result = await googleProvider.signInWithOAuth(from: viewController)
        switch result {
        case .success:
            provider = googleProvider
            session = await provider.getSession()
            sessionVersion += 1
            if let s = session {
                print("[Auth] Usuario autenticado (Google): \(s.email ?? "sin email") (userId: \(s.userId))")
            }
        case .failure(let error):
            throw error
        }
    }
}

extension Notification.Name {
    /// Se envía cuando el usuario cierra sesión; RootView lo usa para forzar la transición a LoginView.
    static let authDidSignOut = Notification.Name("authDidSignOut")
}
