//
//  ClipboardTransactionParser.swift
//  FinanceFlow
//
//  Parsea mensajes de banco/SMS copiados al portapapeles para extraer
//  monto, descripción y fecha (ej. DAVIbank, Bancolombia, etc.).
//

import Foundation

/// Resultado del parseo de un mensaje de transacción (SMS/notificación de banco).
struct ParsedClipboardTransaction {
    var amount: Decimal
    var note: String
    var date: Date
    /// Por defecto gasto; mensajes con "recibiste" o "ingreso" se pueden marcar como ingreso.
    var type: TransactionType
}

/// Parsea texto de notificaciones bancarias o SMS para extraer monto, comercio y fecha.
enum ClipboardTransactionParser {
    private static let amountPattern = #"por\s+([0-9][0-9.,\s]*\d)"#
    /// Captura el texto entre "en " y " por " (comercio/descripción).
    private static let merchantPattern = #"(?:transaccion|transacción)\s+en\s+(.+?)\s+por\s+"#
    private static let altMerchantPattern = #"en\s+(.+?)\s+por\s+"#
    private static let dateTimePattern = #"(\d{4})[/-](\d{2})[/-](\d{2})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?"#
    private static let dateOnlyPattern = #"(\d{2})[/-](\d{2})[/-](\d{4})"#

    /// Intenta parsear una cadena como mensaje de transacción bancaria.
    /// - Parameter text: Texto copiado (por ejemplo desde SMS o notificación).
    /// - Returns: Datos parseados o `nil` si no se reconoce el formato.
    static func parse(_ text: String) -> ParsedClipboardTransaction? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let amount = extractAmount(from: trimmed),
              amount > 0 else { return nil }

        let note = extractNote(from: trimmed)
        let date = extractDate(from: trimmed) ?? Date()
        let type = inferTransactionType(from: trimmed)

        return ParsedClipboardTransaction(
            amount: amount,
            note: note,
            date: date,
            type: type
        )
    }

    /// Extrae el monto (ej. "por 49,600" → 49600).
    private static func extractAmount(from text: String) -> Decimal? {
        let nsText = text as NSString
        guard let regex = try? NSRegularExpression(pattern: amountPattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)),
              match.range(at: 1).location != NSNotFound else { return nil }

        var amountStr = nsText.substring(with: match.range(at: 1))
            .replacingOccurrences(of: " ", with: "")
        // Separador de miles: coma o punto (ej. 49,600 o 1.234)
        if amountStr.contains(",") && !amountStr.contains(".") {
            amountStr = amountStr.replacingOccurrences(of: ",", with: "")
        } else if amountStr.contains(".") && !amountStr.contains(",") {
            // Punto como miles (ej. 1.234) o decimal (ej. 49.60)
            let parts = amountStr.split(separator: ".")
            let looksLikeDecimal = parts.count == 2 && parts[1].count == 2
            if !looksLikeDecimal {
                amountStr = amountStr.replacingOccurrences(of: ".", with: "")
            }
        }

        return Decimal(string: amountStr)
    }

    /// Extrae la descripción/comercio (ej. "en RAPPI COLOMBIA*DL" → "RAPPI COLOMBIA*DL").
    private static func extractNote(from text: String) -> String {
        let nsText = text as NSString
        let patterns = [merchantPattern, altMerchantPattern]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)),
               match.range(at: 1).location != NSNotFound {
                return nsText.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }

    /// Extrae fecha/hora (ej. "2026/02/07 19:13:48").
    private static func extractDate(from text: String) -> Date? {
        let nsText = text as NSString
        if let regex = try? NSRegularExpression(pattern: dateTimePattern),
           let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)),
           match.numberOfRanges >= 6 {
            let r1 = match.range(at: 1), r2 = match.range(at: 2), r3 = match.range(at: 3)
            let r4 = match.range(at: 4), r5 = match.range(at: 5)
            guard r1.location != NSNotFound, let y = Int(nsText.substring(with: r1)),
                  let mo = Int(nsText.substring(with: r2)),
                  let d = Int(nsText.substring(with: r3)),
                  let h = Int(nsText.substring(with: r4)),
                  let min = Int(nsText.substring(with: r5)) else { return nil }
            let sec: Int
            if match.numberOfRanges > 6 {
                let r6 = match.range(at: 6)
                sec = r6.location != NSNotFound ? Int(nsText.substring(with: r6)) ?? 0 : 0
            } else {
                sec = 0
            }
            var comp = DateComponents()
            comp.year = y
            comp.month = mo
            comp.day = d
            comp.hour = h
            comp.minute = min
            comp.second = sec
            return Calendar.current.date(from: comp)
        }
        if let regex = try? NSRegularExpression(pattern: dateOnlyPattern),
           let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)),
           match.numberOfRanges >= 4 {
            let r1 = match.range(at: 1), r2 = match.range(at: 2), r3 = match.range(at: 3)
            guard r1.location != NSNotFound, let d = Int(nsText.substring(with: r1)),
                  let mo = Int(nsText.substring(with: r2)),
                  let y = Int(nsText.substring(with: r3)) else { return nil }
            var comp = DateComponents()
            comp.year = y
            comp.month = mo
            comp.day = d
            return Calendar.current.date(from: comp)
        }
        return nil
    }

    /// Infiere si es gasto o ingreso según palabras clave del mensaje.
    private static func inferTransactionType(from text: String) -> TransactionType {
        let lower = text.lowercased()
        if lower.contains("recibiste") || lower.contains("ingreso") || lower.contains("abono") {
            return .income
        }
        return .expense
    }
}
