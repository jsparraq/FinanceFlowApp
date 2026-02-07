//
//  SupabaseClient.swift
//  FinanceFlow
//
//  Cliente singleton de Supabase.
//

import Foundation
import Supabase

/// Configuración del proyecto Supabase
/// TODO: Mover a Info.plist o variables de entorno en producción
enum SupabaseConfig {
    static let urlString = "https://TU_PROYECTO.supabase.co"
    static let anonKey = "TU_ANON_KEY"
}

/// Cliente singleton de Supabase para toda la app
enum SupabaseClientService {
    static let shared: SupabaseClient = {
        guard let url = URL(string: SupabaseConfig.urlString) else {
            fatalError("Supabase URL inválida. Configura SupabaseConfig en SupabaseClient.swift")
        }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: SupabaseConfig.anonKey
        )
    }()
}
