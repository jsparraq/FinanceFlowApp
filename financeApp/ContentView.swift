//
//  ContentView.swift
//  FinanceFlow
//
//  Vista raíz con TabView: Dashboard, Transacciones.
//  El botón + en la toolbar abre AddTransactionView.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = TransactionViewModel()
    @State private var showingAddTransaction = false

    var body: some View {
        TabView {
            NavigationStack {
                DashboardView()
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
                    }
            }
            .tabItem {
                Label("Transacciones", systemImage: "list.bullet")
            }
        }
        .environment(viewModel)
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
}
