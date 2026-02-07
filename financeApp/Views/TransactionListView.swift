//
//  TransactionListView.swift
//  FinanceFlow
//
//  Lista elegante de transacciones recientes.
//

import SwiftUI

struct TransactionListView: View {
    @Environment(TransactionViewModel.self) private var viewModel

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
            ForEach(viewModel.transactions) { transaction in
                TransactionRowView(
                    transaction: transaction,
                    category: viewModel.category(for: transaction.categoryId)
                )
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
}

// MARK: - Transaction Row

struct TransactionRowView: View {
    let transaction: Transaction
    let category: Category?

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
            Text(transaction.date, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
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
