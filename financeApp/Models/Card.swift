//
//  Card.swift
//  FinanceFlow
//
//  Modelo de tarjeta (débito o crédito).
//

import Foundation

/// Tipo de tarjeta: débito, crédito o efectivo
enum CardType: String, Codable, CaseIterable, Identifiable {
    case debit = "debit"
    case credit = "credit"
    case cash = "cash"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .debit: return "Débito"
        case .credit: return "Crédito"
        case .cash: return "Efectivo"
        }
    }

    var iconName: String {
        switch self {
        case .debit: return "creditcard"
        case .credit: return "creditcard.fill"
        case .cash: return "banknote"
        }
    }

    /// Tipos que el usuario puede crear (efectivo es solo tarjeta del sistema)
    static var userCreatable: [CardType] {
        [.debit, .credit]
    }
}

/// Representa una tarjeta bancaria
struct Card: Identifiable, Codable, Equatable, Hashable {
    /// UUID fijo de la tarjeta sistema "Efectivo" (pagos en efectivo)
    static let efectivoId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    let id: UUID
    var name: String
    var type: CardType
    /// Cupo máximo (solo para tarjetas de crédito). nil en débito.
    var creditLimit: Decimal?
    /// Día del mes en que cierra el ciclo de facturación (1-31). Solo crédito.
    var cutoffDay: Int?
    /// Día del mes límite para pagar (1-31). Solo crédito.
    var paymentDueDay: Int?
    var createdAt: Date?
    var updatedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        type: CardType,
        creditLimit: Decimal? = nil,
        cutoffDay: Int? = nil,
        paymentDueDay: Int? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.creditLimit = (type == .credit ? creditLimit : nil)
        self.cutoffDay = (type == .credit ? cutoffDay : nil)
        self.paymentDueDay = (type == .credit ? paymentDueDay : nil)
        self.createdAt = createdAt ?? Date()
        self.updatedAt = updatedAt ?? Date()
    }

    /// Indica si es tarjeta de crédito (tiene cupo)
    var isCredit: Bool { type == .credit }

    /// Indica si es la tarjeta sistema "Efectivo" (no se puede eliminar)
    var isSystemEfectivo: Bool { id == Self.efectivoId }

    // MARK: - Codable (Supabase/PostgreSQL)

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case creditLimit = "credit_limit"
        case cutoffDay = "cutoff_day"
        case paymentDueDay = "payment_due_day"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
