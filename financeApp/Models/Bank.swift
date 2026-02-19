//
//  Bank.swift
//  FinanceFlow
//
//  Protocolo para bancos que envían notificaciones por email.
//  Cada banco implementa su parser para extraer monto, comercio y fecha del snippet.
//

import Foundation

/// Factory para obtener el parser según el banco
enum BankParserFactory {
    static func parser(for bank: Bank) -> BankEmailParser? {
        switch bank {
        case .nubank: return NubankEmailParser()
        case .bancolombia, .daviplata: return nil
        }
    }
}

/// Banco soportado para importar gastos desde Gmail
enum Bank: String, CaseIterable, Identifiable {
    case nubank = "Nubank"
    case bancolombia = "Bancolombia"
    case daviplata = "Daviplata"

    var id: String { rawValue }

    var displayName: String { rawValue }

    /// Indica si el parser está implementado para este banco
    var hasParser: Bool {
        switch self {
        case .nubank: return true
        case .bancolombia, .daviplata: return false
        }
    }
}

/// Resultado del parseo de un email de notificación bancaria
struct ParsedBankExpense {
    var amount: Decimal
    var note: String
    var date: Date
    var gmailMessageId: String
}

/// Protocolo que deben implementar los parsers de cada banco
protocol BankEmailParser {
    /// Banco al que aplica este parser
    var bank: Bank { get }

    /// Intenta parsear el snippet de un email para extraer gasto
    /// - Parameters:
    ///   - snippet: Texto del snippet del email
    ///   - internalDateMs: Fecha del email en milisegundos (epoch)
    ///   - messageId: ID del mensaje en Gmail (para trazabilidad)
    /// - Returns: Gasto parseado o nil si no se reconoce el formato
    func parse(snippet: String, internalDateMs: String?, messageId: String) -> ParsedBankExpense?
}
