//
//  FinanceRepository.swift
//  FinanceFlow
//
//  Repositorio para operaciones CRUD de transacciones.
//  Punto de integración para: LLM (análisis), SMS (extracción automática).
//

import Foundation
import Supabase

/// Errores del repositorio
enum FinanceRepositoryError: Error {
    case supabaseNotAvailable
    case decodeError
    case networkError(Error)
}

/// Repositorio principal de finanzas - CRUD de transacciones
@MainActor
final class FinanceRepository {
    static let shared = FinanceRepository()
    private let client = SupabaseClientService.shared

    private init() {}

    // MARK: - Transacciones (CRUD)

    /// Obtiene todas las transacciones del usuario actual
    func fetchTransactions() async throws -> [Transaction] {
        let response: [Transaction] = try await client
            .from("transactions")
            .select()
            .order("date", ascending: false)
            .execute()
            .value
        return response
    }

    /// Obtiene una transacción por ID
    func fetchTransaction(id: UUID) async throws -> Transaction? {
        let response: [Transaction] = try await client
            .from("transactions")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        return response.first
    }

    /// Crea una nueva transacción
    /// TODO: Integrar con LLM para categorización automática si la nota contiene texto libre
    /// TODO: Integrar con parser de SMS para extraer monto/fecha desde mensajes
    func createTransaction(_ transaction: Transaction) async throws {
        try await client
            .from("transactions")
            .insert(transaction)
            .execute()
    }

    /// Actualiza una transacción existente
    func updateTransaction(_ transaction: Transaction) async throws {
        try await client
            .from("transactions")
            .update(transaction)
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

    // MARK: - Categorías (lectura por ahora)

    func fetchCategories() async throws -> [Category] {
        let response: [Category] = try await client
            .from("categories")
            .select()
            .execute()
            .value
        return response.isEmpty ? Category.allDefaults : response
    }
}
