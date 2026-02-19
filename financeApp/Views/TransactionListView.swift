//
//  TransactionListView.swift
//  FinanceFlow
//
//  Lista elegante de transacciones recientes.
//

import SwiftUI

/// Opción de filtro por tarjeta en la lista de transacciones
private enum CardFilterOption: Hashable {
    case all
    case noCard
    case card(UUID)
}

struct TransactionListView: View {
    @Environment(TransactionViewModel.self) private var viewModel
    @State private var selectedFilter: CardFilterOption = .all

    private var filteredTransactions: [Transaction] {
        switch selectedFilter {
        case .all:
            return viewModel.transactions
        case .noCard:
            return viewModel.transactions.filter { $0.cardId == nil }
        case .card(let id):
            return viewModel.transactions.filter { $0.cardId == id }
        }
    }

    private var emptyFilterTitle: String {
        switch selectedFilter {
        case .all: return "Sin transacciones"
        case .noCard: return "Sin transacciones sin tarjeta"
        case .card: return "Sin transacciones para esta tarjeta"
        }
    }

    private var emptyFilterDescription: String {
        switch selectedFilter {
        case .all: return "Agrega tu primera transacción para comenzar el seguimiento."
        case .noCard: return "No hay transacciones sin tarjeta asignada."
        case .card: return "No hay transacciones asociadas a la tarjeta seleccionada."
        }
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Cargando...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.transactions.isEmpty {
                emptyState
            } else {
                transactionList
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Transacciones")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Sin transacciones", systemImage: "tray")
        } description: {
            Text("Agrega tu primera transacción para comenzar el seguimiento.")
        }
    }

    private var transactionList: some View {
        List {
            Section {
                Picker("Filtrar por tarjeta", selection: $selectedFilter) {
                    Text("Todas").tag(CardFilterOption.all)
                    Text("Sin tarjeta").tag(CardFilterOption.noCard)
                    ForEach(viewModel.cards) { card in
                        Label(card.name, systemImage: card.type.iconName)
                            .tag(CardFilterOption.card(card.id))
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("Filtro")
            }

            if filteredTransactions.isEmpty {
                ContentUnavailableView {
                    Label(emptyFilterTitle, systemImage: "creditcard")
                } description: {
                    Text(emptyFilterDescription)
                }
            } else {
                ForEach(filteredTransactions) { transaction in
                    NavigationLink(value: transaction) {
                    TransactionRowView(
                        transaction: transaction,
                        category: viewModel.category(for: transaction.categoryId),
                        card: viewModel.card(for: transaction.cardId)
                    )
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteTransaction(transaction) }
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                }
                }
            }
        }
        .navigationDestination(for: Transaction.self) { transaction in
            EditTransactionView(transaction: transaction)
        }
    }
}

// MARK: - Transaction Row

struct TransactionRowView: View {
    let transaction: Transaction
    let category: Category?
    let card: Card?

    var body: some View {
        HStack(spacing: 12) {
            categoryIcon
            transactionInfo
            Spacer()
            amountLabel
        }
        .padding(.vertical, 4)
    }

    private var categoryIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill((category?.color ?? .gray).opacity(0.2))
                .frame(width: 44, height: 44)
            Image(systemName: category?.iconName ?? "questionmark.circle")
                .font(.title3)
                .foregroundStyle(category?.color ?? .gray)
        }
    }

    private var transactionInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(category?.name ?? "Sin categoría")
                .font(.headline)
            HStack(spacing: 4) {
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let card {
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(card.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let note = transaction.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var amountLabel: some View {
        Text(CurrencyFormatter.shared.formatSigned(transaction.signedAmount))
            .font(.headline)
            .foregroundStyle(transaction.type == .income ? .green : .red)
    }
}

#Preview {
    NavigationStack {
        TransactionListView()
            .environment(TransactionViewModel())
    }
}
