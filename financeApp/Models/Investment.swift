//
//  Investment.swift
//  FinanceFlow
//
//  Modelo base para seguimiento de inversiones.
//  Escalable para acciones, fondos, criptomonedas, etc.
//

import Foundation

/// Tipo de activo de inversión (extensible)
enum InvestmentType: String, Codable, CaseIterable, Identifiable {
    case stock = "stock"
    case fund = "fund"
    case crypto = "crypto"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .stock: return "Acciones"
        case .fund: return "Fondos"
        case .crypto: return "Criptomonedas"
        case .other: return "Otros"
        }
    }
}

/// Representa una posición de inversión
/// Nota: Este modelo está preparado para expansión futura.
struct Investment: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var symbol: String?
    var type: InvestmentType
    var amountInvested: Decimal
    var currentValue: Decimal?
    var quantity: Decimal
    var currency: String
    var createdAt: Date
    var updatedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        symbol: String? = nil,
        type: InvestmentType = .other,
        amountInvested: Decimal,
        currentValue: Decimal? = nil,
        quantity: Decimal = 1,
        currency: String = "USD",
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.type = type
        self.amountInvested = amountInvested
        self.currentValue = currentValue ?? amountInvested
        self.quantity = quantity
        self.currency = currency
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    /// Retorno porcentual si hay valor actual
    var returnPercentage: Decimal? {
        guard let current = currentValue, amountInvested > 0 else { return nil }
        return ((current - amountInvested) / amountInvested) * 100
    }

    // MARK: - Codable (Supabase/PostgreSQL)

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case symbol
        case type
        case amountInvested = "amount_invested"
        case currentValue = "current_value"
        case quantity
        case currency
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
