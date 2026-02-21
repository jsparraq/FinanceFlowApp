//
//  FinanceRepository.swift
//  FinanceFlow
//
//  Repositorio para operaciones CRUD de transacciones.
//  Los montos se cifran antes de enviar a la BD y se descifran al leer.
//

import Foundation
import Supabase

/// Errores del repositorio
enum FinanceRepositoryError: Error {
    case supabaseNotAvailable
    case decodeError
    case networkError(Error)
    case encryptionError(EncryptionError)
}

/// Repositorio principal de finanzas - CRUD de transacciones
@MainActor
final class FinanceRepository {
    static let shared = FinanceRepository()
    private let client = SupabaseClientService.shared

    private init() {}

    /// Obtiene el user_id de la sesión actual (necesario para cifrado)
    private func currentUserId() async throws -> UUID {
        let session = try await client.auth.session
        return session.user.id
    }

    // MARK: - Transacciones (CRUD)

    /// Obtiene todas las transacciones del usuario actual (descifrando los montos)
    func fetchTransactions() async throws -> [Transaction] {
        let userId = try await currentUserId()
        let rows: [TransactionRow] = try await client
            .from("transactions")
            .select()
            .order("date", ascending: false)
            .execute()
            .value
        return try rows.map { row in
            try rowToTransaction(row, userId: userId)
        }
    }

    /// Obtiene una transacción por ID
    func fetchTransaction(id: UUID) async throws -> Transaction? {
        let userId = try await currentUserId()
        let rows: [TransactionRow] = try await client
            .from("transactions")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let row = rows.first else { return nil }
        return try rowToTransaction(row, userId: userId)
    }

    /// Crea una nueva transacción (cifrando el monto antes de enviar)
    func createTransaction(_ transaction: Transaction) async throws {
        let userId = try await currentUserId()
        let encryptedAmount = try TransactionEncryptionService.encrypt(amount: transaction.amount, userId: userId)
        let payload = TransactionEncoded(
            id: transaction.id,
            amount: encryptedAmount,
            categoryId: transaction.categoryId,
            cardId: transaction.cardId,
            creditCardPaidId: transaction.creditCardPaidId,
            date: transaction.date,
            note: transaction.note,
            type: transaction.type.rawValue,
            fixedVariable: transaction.fixedVariable.rawValue,
            createdAt: transaction.createdAt,
            updatedAt: transaction.updatedAt
        )
        try await client
            .from("transactions")
            .insert(payload)
            .execute()
    }

    /// Actualiza una transacción existente (cifrando el monto)
    func updateTransaction(_ transaction: Transaction) async throws {
        let userId = try await currentUserId()
        let encryptedAmount = try TransactionEncryptionService.encrypt(amount: transaction.amount, userId: userId)
        let payload = TransactionEncoded(
            id: transaction.id,
            amount: encryptedAmount,
            categoryId: transaction.categoryId,
            cardId: transaction.cardId,
            creditCardPaidId: transaction.creditCardPaidId,
            date: transaction.date,
            note: transaction.note,
            type: transaction.type.rawValue,
            fixedVariable: transaction.fixedVariable.rawValue,
            createdAt: transaction.createdAt,
            updatedAt: transaction.updatedAt
        )
        try await client
            .from("transactions")
            .update(payload)
            .eq("id", value: transaction.id.uuidString)
            .execute()
    }

    /// Elimina una transacción
    func deleteTransaction(id: UUID) async throws {
        try await client
            .from("transactions")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Helpers cifrado

    private func rowToTransaction(_ row: TransactionRow, userId: UUID) throws -> Transaction {
        let amount = try TransactionEncryptionService.decrypt(encryptedBase64: row.amount, userId: userId)
        guard let type = TransactionType(rawValue: row.type) else {
            throw FinanceRepositoryError.decodeError
        }
        let fixedVariable = (row.fixedVariable.flatMap { TransactionFixedVariable(rawValue: $0) }) ?? .variable
        return Transaction(
            id: row.id,
            amount: amount,
            categoryId: row.categoryId,
            cardId: row.cardId,
            creditCardPaidId: row.creditCardPaidId,
            date: row.date,
            note: row.note,
            type: type,
            fixedVariable: fixedVariable,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt
        )
    }

    // MARK: - Tarjetas (CRUD)

    /// Obtiene todas las tarjetas del usuario actual
    func fetchCards() async throws -> [Card] {
        let response: [Card] = try await client
            .from("cards")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        return response
    }

    /// Crea una nueva tarjeta
    func createCard(_ card: Card) async throws {
        try await client
            .from("cards")
            .insert(card)
            .execute()
    }

    /// Actualiza una tarjeta existente
    func updateCard(_ card: Card) async throws {
        try await client
            .from("cards")
            .update(card)
            .eq("id", value: card.id.uuidString)
            .execute()
    }

    /// Elimina una tarjeta
    func deleteCard(id: UUID) async throws {
        try await client
            .from("cards")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: - Conexión (diagnóstico)

    /// Comprueba la conexión a Supabase leyendo la tabla de categorías.
    /// Útil para validar URL, anon key y que las migraciones estén aplicadas.
    func checkConnection() async -> Result<Int, Error> {
        do {
            let list: [Category] = try await client
                .from("categories")
                .select()
                .execute()
                .value
            return .success(list.count)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Categorías (lectura por ahora)

    /// Carga categorías desde la BD. Si la tabla está vacía, ejecuta el seed
    /// en la BD y vuelve a cargar, para que los category_id existan siempre
    /// y no falle la FK al insertar transacciones.
    func fetchCategories() async throws -> [Category] {
        var response: [Category] = try await client
            .from("categories")
            .select()
            .execute()
            .value
        if response.isEmpty {
            try await client.rpc("seed_categories_if_empty").execute()
            response = try await client
                .from("categories")
                .select()
                .execute()
                .value
        }
        // Solo devolver categorías que existen en la BD (nunca allDefaults aquí)
        // para que los category_id sean siempre válidos en inserts.
        return response
    }
}
