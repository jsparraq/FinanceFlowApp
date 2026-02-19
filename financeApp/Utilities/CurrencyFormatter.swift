//
//  CurrencyFormatter.swift
//  FinanceFlow
//
//  Helper para formatear montos en pesos (COP/MXN) y dólares (USD).
//  Mantiene consistencia en toda la app.
//

import Foundation

/// Códigos ISO de moneda soportados
enum CurrencyCode: String, CaseIterable, Identifiable {
    case usd = "USD"
    case cop = "COP"
    case mxn = "MXN"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .usd: return "Dólares (USD)"
        case .cop: return "Pesos (COP)"
        case .mxn: return "Pesos (MXN)"
        }
    }

    var symbol: String {
        switch self {
        case .usd: return "$"
        case .cop: return "$"
        case .mxn: return "$"
        }
    }

    /// Cantidad de decimales a mostrar
    var fractionDigits: Int {
        switch self {
        case .usd: return 2
        case .cop, .mxn: return 0 // Pesos típicamente sin decimales
        }
    }

    /// Locale para formateo
    var locale: Locale {
        switch self {
        case .usd: return Locale(identifier: "en_US")
        case .cop: return Locale(identifier: "es_CO")
        case .mxn: return Locale(identifier: "es_MX")
        }
    }
}

/// Formateador de moneda centralizado
struct CurrencyFormatter {
    static let shared = CurrencyFormatter()

    private let formatters: [CurrencyCode: NumberFormatter] = {
        var result: [CurrencyCode: NumberFormatter] = [:]
        for code in CurrencyCode.allCases {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = code.rawValue
            formatter.locale = code.locale
            formatter.minimumFractionDigits = code.fractionDigits
            formatter.maximumFractionDigits = code.fractionDigits
            result[code] = formatter
        }
        return result
    }()

    private init() {}

    /// Formatea un monto con la moneda especificada
    func format(_ amount: Decimal, currency: CurrencyCode = .usd) -> String {
        formatters[currency]?.string(from: amount as NSDecimalNumber) ?? "\(currency.symbol)\(amount)"
    }

    /// Formatea un monto con signo (para ingresos/gastos)
    func formatSigned(_ amount: Decimal, currency: CurrencyCode = .usd) -> String {
        let formatted = format(abs(amount), currency: currency)
        if amount >= 0 {
            return "+\(formatted)"
        }
        return "-\(formatted)"
    }

    /// Formatea un monto para edición en TextField (sin símbolo de moneda)
    func formatForInput(_ amount: Decimal, currency: CurrencyCode = .usd) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = currency.locale
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = currency.fractionDigits
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    /// Formatea un monto para exportación CSV: sin símbolo, sin separador de miles, solo punto decimal
    /// Ej: 8900.00 (USD) o 8900 (COP/MXN como entero)
    func formatForExport(_ amount: Decimal, currency: CurrencyCode = .usd) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX") // Evita comas en miles
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = currency.fractionDigits
        formatter.maximumFractionDigits = currency.fractionDigits
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }

    /// Parsea un string a Decimal (para inputs de usuario)
    func parse(_ string: String, currency: CurrencyCode = .usd) -> Decimal? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = currency.locale
        formatter.generatesDecimalNumbers = true
        return formatter.number(from: string) as? Decimal
    }
}
