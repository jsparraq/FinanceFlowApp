//
//  AuthViewModel.swift
//  FinanceFlow
//
//  ViewModel para login y registro. Usa AuthService (Factory de proveedores).
//

import Foundation
import SwiftUI
import UIKit

@MainActor
@Observable
final class AuthViewModel {
    var email = ""
    var password = ""
    var confirmPassword = ""
    var isLoading = false
    var errorMessage: String?
    var showingSignUp = false

    private let authService: AuthService

    var isAuthenticated: Bool { authService.isAuthenticated }

    init(authService: AuthService) {
        self.authService = authService
    }

    func signIn() async {
        guard validateEmailPassword(isSignUp: false) else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await authService.signIn(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signUp() async {
        guard validateEmailPassword(isSignUp: true) else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await authService.signUp(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() async {
        print("[Auth] signOut llamado")
        isLoading = true
        errorMessage = nil
        do {
            try await authService.signOut()
            print("[Auth] signOut completado sin error")
        } catch {
            print("[Auth] signOut error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refreshSession() async {
        await authService.refreshSession()
    }

    /// Inicia sesión con Google. Requiere el view controller raíz para presentar el flujo OAuth.
    func signInWithGoogle(from viewController: UIViewController) async {
        isLoading = true
        errorMessage = nil
        do {
            try await authService.signInWithGoogle(from: viewController)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func validateEmailPassword(isSignUp: Bool) -> Bool {
        email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else {
            errorMessage = "Introduce tu correo."
            return false
        }
        guard email.contains("@"), email.contains(".") else {
            errorMessage = "Correo no válido."
            return false
        }
        guard !password.isEmpty else {
            errorMessage = "Introduce tu contraseña."
            return false
        }
        if isSignUp {
            guard password.count >= 6 else {
                errorMessage = "La contraseña debe tener al menos 6 caracteres."
                return false
            }
            guard password == confirmPassword else {
                errorMessage = "Las contraseñas no coinciden."
                return false
            }
        }
        return true
    }
}
