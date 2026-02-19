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
    var cards: [Card] = []
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

    /// Transacciones del mes actual
    var transactionsCurrentMonth: [Transaction] {
        let calendar = Calendar.current
        let now = Date()
        return transactions.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
    }

    /// Ingresos del mes actual
    var totalIncomeCurrentMonth: Decimal {
        transactionsCurrentMonth.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    /// Gastos del mes actual
    var totalExpensesCurrentMonth: Decimal {
        transactionsCurrentMonth.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    /// Datos para gráfico de barras: día del mes → (ingresos, egresos)
    struct DayAmount: Identifiable {
        let id: Int
        let day: Int
        let income: Decimal
        let expenses: Decimal
    }

    var transactionsByDayCurrentMonth: [DayAmount] {
        let calendar = Calendar.current
        let monthTx = transactionsCurrentMonth
        var byDay: [Int: (income: Decimal, expenses: Decimal)] = [:]
        for tx in monthTx {
            let day = calendar.component(.day, from: tx.date)
            var current = byDay[day] ?? (0, 0)
            switch tx.type {
            case .income: current.income += tx.amount
            case .expense: current.expenses += tx.amount
            }
            byDay[day] = current
        }
        let daysInMonth = calendar.range(of: .day, in: .month, for: Date())?.count ?? 31
        return (1...daysInMonth).map { day in
            let data = byDay[day] ?? (0, 0)
            return DayAmount(id: day, day: day, income: data.income, expenses: data.expenses)
        }
    }

    /// Datos aplanados para gráfico de barras agrupadas (ingresos/egresos por día)
    struct DayBarItem: Identifiable {
        let id: String
        let day: Int
        let amount: Decimal
        let isIncome: Bool
    }

    var barChartDataCurrentMonth: [DayBarItem] {
        transactionsByDayCurrentMonth.flatMap { d in
            [
                DayBarItem(id: "\(d.day)-income", day: d.day, amount: d.income, isIncome: true),
                DayBarItem(id: "\(d.day)-expense", day: d.day, amount: -d.expenses, isIncome: false)
            ]
        }
    }

    /// Datos para gráfico de pastel de ingresos por categoría (mes actual)
    struct CategorySlice: Identifiable {
        let id: UUID
        let name: String
        let amount: Decimal
        let color: Color
    }

    var incomeByCategoryCurrentMonth: [CategorySlice] {
        let monthTx = transactionsCurrentMonth.filter { $0.type == .income }
        var byCategory: [UUID: Decimal] = [:]
        for tx in monthTx {
            byCategory[tx.categoryId, default: 0] += tx.amount
        }
        return byCategory.compactMap { categoryId, amount in
            guard amount > 0, let cat = category(for: categoryId) else { return nil }
            return CategorySlice(id: categoryId, name: cat.name, amount: amount, color: cat.color)
        }.sorted { $0.amount > $1.amount }
    }

    /// Datos para gráfico de pastel de egresos por categoría (mes actual)
    var expensesByCategoryCurrentMonth: [CategorySlice] {
        let monthTx = transactionsCurrentMonth.filter { $0.type == .expense }
        var byCategory: [UUID: Decimal] = [:]
        for tx in monthTx {
            byCategory[tx.categoryId, default: 0] += tx.amount
        }
        return byCategory.compactMap { categoryId, amount in
            guard amount > 0, let cat = category(for: categoryId) else { return nil }
            return CategorySlice(id: categoryId, name: cat.name, amount: amount, color: cat.color)
        }.sorted { $0.amount > $1.amount }
    }

    // MARK: - Actions

    /// Carga transacciones y categorías desde el repositorio.
    /// Si una de las cargas falla, la otra se intenta igualmente para dar mejor UX
    /// (p. ej. poder agregar transacciones aunque la lista de transacciones no cargue).
    func loadData() async {
        isLoading = true
        errorMessage = nil

        let txTask = Task { try await repository.fetchTransactions() }
        let catTask = Task { try await repository.fetchCategories() }
        let cardsTask = Task { try await repository.fetchCards() }

        var lastError: Error?

        do {
            transactions = try await txTask.value
        } catch {
            transactions = []
            lastError = error
        }

        do {
            categories = try await catTask.value
        } catch {
            categories = []
            lastError = lastError ?? error
        }

        do {
            cards = try await cardsTask.value
        } catch {
            cards = []
            lastError = lastError ?? error
        }

        errorMessage = lastError?.localizedDescription
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

    /// Obtiene la tarjeta por ID
    func card(for id: UUID?) -> Card? {
        guard let id else { return nil }
        return cards.first { $0.id == id }
    }

    // MARK: - Tarjetas

    /// Agrega una tarjeta
    func addCard(_ card: Card) async {
        do {
            try await repository.createCard(card)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Actualiza una tarjeta
    func updateCard(_ card: Card) async {
        do {
            try await repository.updateCard(card)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Elimina una tarjeta
    func deleteCard(_ card: Card) async {
        do {
            try await repository.deleteCard(id: card.id)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
