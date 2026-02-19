//
//  SignUpView.swift
//  FinanceFlow
//
//  Pantalla de registro con correo y contraseña.
//

import SwiftUI

struct SignUpView: View {
    @Bindable var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Correo", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField("Contraseña", text: $viewModel.password)
                        .textContentType(.newPassword)

                    SecureField("Repetir contraseña", text: $viewModel.confirmPassword)
                        .textContentType(.newPassword)
                } header: {
                    Text("Nueva cuenta")
                } footer: {
                    Text("Mínimo 6 caracteres. La contraseña se guarda de forma segura (hash) en el servidor.")
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
                        Task {
                            await viewModel.signUp()
                            if viewModel.isAuthenticated { dismiss() }
                        }
                    } label: {
                        HStack {
                            Text("Registrarme")
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .navigationTitle("Crear cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        viewModel.errorMessage = nil
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SignUpView(viewModel: AuthViewModel(authService: AuthService(provider: AuthProviderFactory.defaultProvider)))
}
