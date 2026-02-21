//
//  Transaction.swift
//  FinanceFlow
//
//  Modelo de transacción financiera.
//  Preparado para integración futura con LLM y procesamiento de SMS.
//

import Foundation

/// Naturaleza de la transacción: fija (recurrente) o variable (ocasional)
enum TransactionFixedVariable: String, Codable, CaseIterable, Identifiable {
    case fixed = "fixed"
    case variable = "variable"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fixed: return "Fijo"
        case .variable: return "Variable"
        }
    }
}

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
struct Transaction: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var amount: Decimal
    var categoryId: UUID
    var cardId: UUID?
    /// Tarjeta de crédito que se está pagando (solo cuando es un pago de tarjeta)
    var creditCardPaidId: UUID?
    var date: Date
    var note: String?
    var type: TransactionType
    var fixedVariable: TransactionFixedVariable
    var createdAt: Date?
    var updatedAt: Date?

    init(
        id: UUID = UUID(),
        amount: Decimal,
        categoryId: UUID,
        cardId: UUID? = nil,
        creditCardPaidId: UUID? = nil,
        date: Date = Date(),
        note: String? = nil,
        type: TransactionType,
        fixedVariable: TransactionFixedVariable = .variable,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.amount = amount
        self.categoryId = categoryId
        self.cardId = cardId
        self.creditCardPaidId = creditCardPaidId
        self.date = date
        self.note = note
        self.type = type
        self.fixedVariable = fixedVariable
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
        case cardId = "card_id"
        case creditCardPaidId = "credit_card_paid_id"
        case date
        case note
        case type
        case fixedVariable = "tipo"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - TransactionRow (DTO para BD con amount cifrado)

/// Representación de transacción en la BD: amount es texto cifrado (base64).
/// Solo el repositorio usa este tipo para descifrar al leer.
struct TransactionRow: Codable {
    let id: UUID
    let amount: String // cifrado en base64
    let categoryId: UUID
    let cardId: UUID?
    let creditCardPaidId: UUID?
    let date: Date
    let note: String?
    let type: String
    let fixedVariable: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case amount
        case categoryId = "category_id"
        case cardId = "card_id"
        case creditCardPaidId = "credit_card_paid_id"
        case date
        case note
        case type
        case fixedVariable = "tipo"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Payload para insert/update: amount es texto cifrado (base64).
struct TransactionEncoded: Encodable {
    let id: UUID
    let amount: String // cifrado en base64
    let categoryId: UUID
    let cardId: UUID?
    let creditCardPaidId: UUID?
    let date: Date
    let note: String?
    let type: String
    let fixedVariable: String
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case amount
        case categoryId = "category_id"
        case cardId = "card_id"
        case creditCardPaidId = "credit_card_paid_id"
        case date
        case note
        case type
        case fixedVariable = "tipo"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
