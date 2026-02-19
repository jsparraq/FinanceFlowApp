//
//  NubankEmailParser.swift
//  FinanceFlow
//
//  Parsea snippets de emails de Nubank (pagos con Cuenta Nu).
//  Formato: "Pagaste en: [COMERCIO] La cantidad de: $X.XXX,XX"
//

import Foundation

struct NubankEmailParser: BankEmailParser {
    var bank: Bank { .nubank }

    /// Formato Nubank: "Pagaste en: [COMERCIO] La cantidad de: $686.896,00"
    private static let merchantPattern = #"Pagaste en:\s*(.+?)\s+La cantidad de:"#
    /// Monto: $686.896,00 (punto miles, coma decimal) o $686896
    private static let amountPattern = #"La cantidad de:\s*\$?([0-9][0-9.,\s]*\d)"#

    func parse(snippet: String, internalDateMs: String?, messageId: String) -> ParsedBankExpense? {
        guard let amount = extractAmount(from: snippet),
              amount > 0 else { return nil }

        let note = extractMerchant(from: snippet)
        let date = parseDate(internalDateMs: internalDateMs)

        return ParsedBankExpense(
            amount: amount,
            note: note,
            date: date,
            gmailMessageId: messageId
        )
    }

    private func extractAmount(from text: String) -> Decimal? {
        let nsText = text as NSString
        guard let regex = try? NSRegularExpression(pattern: Self.amountPattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)),
              match.range(at: 1).location != NSNotFound else { return nil }

        var amountStr = nsText.substring(with: match.range(at: 1))
            .replacingOccurrences(of: " ", with: "")
        // Formato colombiano: 686.896,00 → 686896.00
        if amountStr.contains(",") && amountStr.contains(".") {
            amountStr = amountStr.replacingOccurrences(of: ".", with: "")
            amountStr = amountStr.replacingOccurrences(of: ",", with: ".")
        } else if amountStr.contains(",") && !amountStr.contains(".") {
            amountStr = amountStr.replacingOccurrences(of: ",", with: ".")
        } else if amountStr.contains(".") && !amountStr.contains(",") {
            let parts = amountStr.split(separator: ".")
            let looksLikeDecimal = parts.count == 2 && parts[1].count == 2
            if !looksLikeDecimal {
                amountStr = amountStr.replacingOccurrences(of: ".", with: "")
            }
        }

        return Decimal(string: amountStr)
    }

    private func extractMerchant(from text: String) -> String {
        let nsText = text as NSString
        guard let regex = try? NSRegularExpression(pattern: Self.merchantPattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)),
              match.range(at: 1).location != NSNotFound else { return "" }
        return nsText.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
    }

    private func parseDate(internalDateMs: String?) -> Date {
        guard let ms = internalDateMs,
              let msInt = Int64(ms) else { return Date() }
        return Date(timeIntervalSince1970: Double(msInt) / 1000)
    }
}
