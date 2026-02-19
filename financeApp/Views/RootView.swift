//
//  RootView.swift
//  FinanceFlow
//
//  Vista raíz: muestra Login si no hay sesión, o ContentView si está autenticado.
//

import SwiftUI

struct RootView: View {
    @Environment(AuthService.self) private var authService
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var transactionViewModel = TransactionViewModel()
    /// Cambia al recibir authDidSignOut para forzar que la vista se re-evalúe y muestre LoginView.
    @State private var signOutViewId = UUID()

    var body: some View {
        Group {
            if authService.isAuthenticated {
                ContentView()
                    .environment(transactionViewModel)
                    .environment(authViewModel)
            } else {
                LoginView(viewModel: authViewModel)
            }
        }
        .id(signOutViewId)
        .onReceive(NotificationCenter.default.publisher(for: .authDidSignOut)) { _ in
            signOutViewId = UUID()
        }
        .task {
            await authViewModel.refreshSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { await authViewModel.refreshSession() }
        }
    }
}

#Preview {
    let authService = AuthService(provider: AuthProviderFactory.defaultProvider)
    RootView()
        .environment(authService)
        .environment(AuthViewModel(authService: authService))
}
