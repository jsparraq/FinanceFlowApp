//
//  ContentView.swift
//  FinanceFlow
//
//  Vista raíz con TabView: Dashboard, Transacciones.
//  El botón + en la toolbar abre AddTransactionView.
//

import SwiftUI

struct ContentView: View {
    @Environment(TransactionViewModel.self) private var viewModel
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var showingAddTransaction = false
    @State private var showingExportSheet = false
    @State private var showingImportFromGmail = false

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
                    .refreshable {
                        await viewModel.loadData()
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cerrar sesión", role: .destructive) {
                                Task { await authViewModel.signOut() }
                            }
                        }
                    }
            }
            .tabItem {
                Label("Dashboard", systemImage: "chart.pie.fill")
            }

            NavigationStack {
                TransactionListView()
                    .refreshable {
                        await viewModel.loadData()
                    }
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                showingAddTransaction = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                            }
                        }
                        ToolbarItem(placement: .secondaryAction) {
                            Button {
                                showingImportFromGmail = true
                            } label: {
                                Label("Importar Gmail", systemImage: "envelope.badge")
                            }
                        }
                        ToolbarItem(placement: .secondaryAction) {
                            Button {
                                showingExportSheet = true
                            } label: {
                                Label("Exportar", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                    .sheet(isPresented: $showingExportSheet) {
                        ExportTransactionsView()
                    }
                    .sheet(isPresented: $showingImportFromGmail) {
                        ImportFromGmailView()
                    }
            }
            .tabItem {
                Label("Transacciones", systemImage: "list.bullet")
            }
        }
        .task {
            await viewModel.loadData()
        }
        .sheet(isPresented: $showingAddTransaction) {
            AddTransactionView()
        }
    }
}

#Preview {
    ContentView()
        .environment(TransactionViewModel())
        .environment(AuthViewModel(authService: AuthService(provider: AuthProviderFactory.defaultProvider)))
}
