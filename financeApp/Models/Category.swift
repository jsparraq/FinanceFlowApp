//
//  Category.swift
//  FinanceFlow
//
//  Modelo de categoría para transacciones.
//  Extensible para soportar iconos y colores personalizados.
//

import SwiftUI

/// Representa una categoría de transacciones
struct Category: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var iconName: String
    var colorHex: String
    var transactionType: TransactionType

    init(
        id: UUID = UUID(),
        name: String,
        iconName: String = "folder",
        colorHex: String = "#6366F1",
        transactionType: TransactionType
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.transactionType = transactionType
    }

    var color: Color {
        Color(hex: colorHex) ?? .indigo
    }

    // MARK: - Codable (Supabase/PostgreSQL)

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case iconName = "icon_name"
        case colorHex = "color_hex"
        case transactionType = "transaction_type"
    }
}

// MARK: - Categorías predefinidas (fallback cuando no hay datos en BD)

extension Category {
    static let defaultExpenseCategories: [Category] = [
        Category(name: "Alimentación", iconName: "fork.knife", colorHex: "#10B981", transactionType: .expense),
        Category(name: "Transporte", iconName: "car.fill", colorHex: "#3B82F6", transactionType: .expense),
        Category(name: "Vivienda", iconName: "house.fill", colorHex: "#8B5CF6", transactionType: .expense),
        Category(name: "Entretenimiento", iconName: "gamecontroller.fill", colorHex: "#EC4899", transactionType: .expense),
        Category(name: "Salud", iconName: "heart.fill", colorHex: "#EF4444", transactionType: .expense),
        Category(name: "Otros", iconName: "ellipsis.circle", colorHex: "#6B7280", transactionType: .expense)
    ]

    static let defaultIncomeCategories: [Category] = [
        Category(name: "Salario", iconName: "banknote.fill", colorHex: "#10B981", transactionType: .income),
        Category(name: "Freelance", iconName: "laptopcomputer", colorHex: "#3B82F6", transactionType: .income),
        Category(name: "Inversiones", iconName: "chart.line.uptrend.xyaxis", colorHex: "#8B5CF6", transactionType: .income),
        Category(name: "Otros", iconName: "plus.circle", colorHex: "#6B7280", transactionType: .income)
    ]

    static let allDefaults: [Category] = defaultExpenseCategories + defaultIncomeCategories
}
