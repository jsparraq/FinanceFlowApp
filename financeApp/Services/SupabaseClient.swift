//
//  SupabaseClient.swift
//  FinanceFlow
//
//  Cliente singleton de Supabase.
//

import Foundation
import Supabase

// MARK: - Coders para fechas (PostgREST devuelve DATE como "yyyy-MM-dd" y TIMESTAMPTZ como ISO8601)

private let supabaseDateDecoder: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .custom { decoder in
        let c = try decoder.singleValueContainer()
        let s = try c.decode(String.self)
        // ISO8601 con hora (created_at, updated_at)
        let iso8601 = ISO8601DateFormatter()
        iso8601.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601.date(from: s) { return date }
        iso8601.formatOptions = [.withInternetDateTime]
        if let date = iso8601.date(from: s) { return date }
        // Solo fecha (columna DATE)
        let dateOnly = DateFormatter()
        dateOnly.dateFormat = "yyyy-MM-dd"
        dateOnly.locale = Locale(identifier: "en_US_POSIX")
        dateOnly.timeZone = TimeZone(secondsFromGMT: 0)
        guard let date = dateOnly.date(from: s) else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Fecha no válida: \(s)")
        }
        return date
    }
    return d
}()

private let supabaseDateEncoder: JSONEncoder = {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    return e
}()

/// Configuración del proyecto Supabase.
/// Los valores se leen de `Secrets.plist` (no se sube a Git).
/// Copia `Secrets.example.plist` → `Secrets.plist` y rellena tu URL y anon key.
enum SupabaseConfig {
    static let urlString: String = {
        guard let url = loadPlistString(key: "SUPABASE_URL"),
              !url.contains("TU_PROYECTO") else {
            fatalError(
                "Configura Supabase: copia Secrets.example.plist a Secrets.plist " +
                "y rellena SUPABASE_URL y SUPABASE_ANON_KEY con tus valores de Supabase."
            )
        }
        return url
    }()

    static let anonKey: String = {
        guard let key = loadPlistString(key: "SUPABASE_ANON_KEY"),
              !key.contains("TU_ANON_KEY") else {
            fatalError(
                "Configura Supabase: copia Secrets.example.plist a Secrets.plist " +
                "y rellena SUPABASE_URL y SUPABASE_ANON_KEY con tus valores de Supabase."
            )
        }
        return key
    }()

    static func loadPlistString(key: String) -> String? {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let value = dict[key] as? String else { return nil }
        return value
    }
}

/// Configuración de Google Sign-In (Client ID de OAuth).
/// Se usa para GIDSignIn y debe coincidir con el configurado en Supabase Dashboard.
enum GoogleConfig {
    static let clientId: String? = SupabaseConfig.loadPlistString(key: "GCP_PROJECT_ID_API")
}

/// Cliente singleton de Supabase para toda la app
enum SupabaseClientService {
    static let shared: SupabaseClient = {
        guard let url = URL(string: SupabaseConfig.urlString) else {
            fatalError("Supabase URL inválida. Configura SupabaseConfig en SupabaseClient.swift")
        }
        let dbOptions = SupabaseClientOptions.DatabaseOptions(
            encoder: supabaseDateEncoder,
            decoder: supabaseDateDecoder
        )
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: SupabaseConfig.anonKey,
            options: SupabaseClientOptions(db: dbOptions)
        )
    }()
}
