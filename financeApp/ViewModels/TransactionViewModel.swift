//
//  TransactionViewModel.swift
//  FinanceFlow
//
//  ViewModel para transacciones usando @Observable (iOS 17+).
//  Punto de conexión para LLM (análisis de gastos) y procesamiento de SMS.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class TransactionViewModel {
    // MARK: - State

    var transactions: [Transaction] = []
    var categories: [Category] = []
    var isLoading = false
    var errorMessage: String?
    var selectedCurrency: CurrencyCode = .usd

    // MARK: - Dependencies

    private let repository = FinanceRepository.shared

    // MARK: - Computed

    /// Saldo total (ingresos - gastos)
    var totalBalance: Decimal {
        transactions.reduce(0) { $0 + $1.signedAmount }
    }

    /// Total de ingresos
    var totalIncome: Decimal {
        transactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    /// Total de gastos
    var totalExpenses: Decimal {
        transactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    /// Transacciones agrupadas por fecha (para el gráfico)
    var transactionsByDate: [(date: Date, amount: Decimal)] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { calendar.startOfDay(for: $0.date) }
        return grouped.map { (date: $0.key, amount: $0.value.reduce(0) { $0 + $1.signedAmount }) }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Actions

    /// Carga transacciones y categorías desde el repositorio
    func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            async let transactionsTask = repository.fetchTransactions()
            async let categoriesTask = repository.fetchCategories()

            let (fetchedTransactions, fetchedCategories) = try await (transactionsTask, categoriesTask)
            transactions = fetchedTransactions
            categories = fetchedCategories.isEmpty ? Category.allDefaults : fetchedCategories
        } catch {
            errorMessage = error.localizedDescription
            // Fallback: usar categorías por defecto
            if categories.isEmpty {
                categories = Category.allDefaults
            }
        }

        isLoading = false
    }

    /// Agrega una transacción
    /// TODO: Integrar LLM para categorización inteligente basada en la nota
    /// TODO: Integrar parser de SMS si el monto/descripción provienen de un mensaje
    func addTransaction(_ transaction: Transaction) async {
        do {
            try await repository.createTransaction(transaction)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Actualiza una transacción
    func updateTransaction(_ transaction: Transaction) async {
        do {
            try await repository.updateTransaction(transaction)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Elimina una transacción
    func deleteTransaction(_ transaction: Transaction) async {
        do {
            try await repository.deleteTransaction(id: transaction.id)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Obtiene la categoría por ID
    func category(for id: UUID) -> Category? {
        categories.first { $0.id == id }
    }
}
