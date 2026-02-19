//
//  financeAppApp.swift
//  FinanceFlow
//
//  Created by Juan Sebastian Parra Quintero on 7/02/26.
//

import SwiftUI
import GoogleSignIn

@main
struct financeAppApp: App {
    private let authService = AuthService(provider: AuthProviderFactory.defaultProvider)
    private let authViewModel: AuthViewModel

    init() {
        authViewModel = AuthViewModel(authService: authService)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authService)
                .environment(authViewModel)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
