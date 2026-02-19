//
//  LoginView.swift
//  FinanceFlow
//
//  Pantalla de inicio de sesión (correo y contraseña y Google).
//

import SwiftUI
import UIKit

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Correo", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .focused($focusedField, equals: .email)

                    SecureField("Contraseña", text: $viewModel.password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                } header: {
                    Text("Iniciar sesión")
                }

                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button {
                        Task { await viewModel.signIn() }
                    } label: {
                        HStack {
                            Text("Entrar")
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.isLoading)

                    Button("Crear cuenta") {
                        viewModel.showingSignUp = true
                        viewModel.errorMessage = nil
                    }
                    .disabled(viewModel.isLoading)
                }

                Section {
                    Button {
                        guard let rootVC = rootViewController else { return }
                        Task { await viewModel.signInWithGoogle(from: rootVC) }
                    } label: {
                        HStack {
                            Image(systemName: "g.circle.fill")
                            Text("Iniciar con Google")
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .navigationTitle("FinanceFlow")
            .sheet(isPresented: $viewModel.showingSignUp) {
                SignUpView(viewModel: viewModel)
            }
        }
    }

    private var rootViewController: UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return nil }
        return rootVC
    }
}

#Preview {
    LoginView(viewModel: AuthViewModel(authService: AuthService(provider: AuthProviderFactory.defaultProvider)))
}
