//
//  Transaction.swift
//  FinanceFlow
//
//  Modelo de transacción financiera.
//  Preparado para integración futura con LLM y procesamiento de SMS.
//

import Foundation

/// Tipo de transacción: ingreso o gasto
enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case income = "income"
    case expense = "expense"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .income: return "Ingreso"
        case .expense: return "Gasto"
        }
    }

    var symbol: String {
        switch self {
        case .income: return "+"
        case .expense: return "-"
        }
    }
}

/// Representa una transacción financiera
struct Transaction: Identifiable, Codable, Equatable {
    let id: UUID
    var amount: Decimal
    var categoryId: UUID
    var date: Date
    var note: String?
    var type: TransactionType
    var createdAt: Date?
    var updatedAt: Date?

    init(
        id: UUID = UUID(),
        amount: Decimal,
        categoryId: UUID,
        date: Date = Date(),
        note: String? = nil,
        type: TransactionType,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.amount = amount
        self.categoryId = categoryId
        self.date = date
        self.note = note
        self.type = type
        self.createdAt = createdAt ?? date
        self.updatedAt = updatedAt ?? date
    }

    /// Monto con signo según el tipo (positivo para ingreso, negativo para gasto)
    var signedAmount: Decimal {
        switch type {
        case .income: return amount
        case .expense: return -amount
        }
    }

    // MARK: - Codable (Supabase/PostgreSQL)

    enum CodingKeys: String, CodingKey {
        case id
        case amount
        case categoryId = "category_id"
        case date
        case note
        case type
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
