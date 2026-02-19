//
//  TransactionExportService.swift
//  FinanceFlow
//
//  Servicio para exportar transacciones a CSV.
//

import Foundation

/// Errores de exportación
enum TransactionExportError: Error {
    case dateRangeTooShort
    case dateRangeTooLong
    case noTransactions
}

/// Servicio para exportar transacciones a CSV
struct TransactionExportService {
    /// Mínimo: 1 semana (7 días). dateComponents.day diff para 7 días = 6
    static let minDayDifference = 6
    /// Máximo: 2 meses (60 días)
    static let maxDayDifference = 60

    /// Valida que el rango de fechas cumpla las restricciones
    static func validateDateRange(from startDate: Date, to endDate: Date) -> Result<Void, TransactionExportError> {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        guard start <= end else {
            return .failure(.dateRangeTooShort)
        }

        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0

        if days < minDayDifference {
            return .failure(.dateRangeTooShort)
        }
        if days > maxDayDifference {
            return .failure(.dateRangeTooLong)
        }
        return .success(())
    }

    /// Genera el contenido CSV de las transacciones filtradas
    /// Columnas: Fecha, Tipo (Ingreso/Egreso), Nombre tarjeta, Tipo tarjeta, Cantidad, Categoría
    static func generateCSV(
        transactions: [Transaction],
        categories: [Category],
        cards: [Card],
        currency: CurrencyCode
    ) -> String {
        let header = "Fecha,Tipo,Nombre tarjeta,Tipo tarjeta,Cantidad,Categoría"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "es")

        let categoryLookup: [UUID: Category] = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let cardLookup: [UUID: Card] = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })

        let rows = transactions.sorted { $0.date < $1.date }.map { tx in
            let dateStr = dateFormatter.string(from: tx.date)
            let tipo = tx.type.displayName
            let card = tx.cardId.flatMap { cardLookup[$0] }
            let cardName = card?.name ?? "Sin tarjeta"
            let cardType = card?.type.displayName ?? "—"
            let amount = CurrencyFormatter.shared.formatForExport(tx.amount, currency: currency)
            let category = categoryLookup[tx.categoryId]?.name ?? "Sin categoría"

            return [dateStr, tipo, escapeCSV(cardName), escapeCSV(cardType), amount, escapeCSV(category)]
                .joined(separator: ",")
        }

        return ([header] + rows).joined(separator: "\n")
    }

    /// Escapa comillas y envuelve en comillas si contiene coma o salto de línea
    private static func escapeCSV(_ value: String) -> String {
        let needsQuotes = value.contains(",") || value.contains("\n") || value.contains("\"")
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return needsQuotes ? "\"\(escaped)\"" : escaped
    }
}
