//
//  TransactionEncryptionService.swift
//  FinanceFlow
//
//  Cifra los montos de transacciones con una clave única por usuario y dispositivo.
//  La clave se guarda en Keychain (semilla del celular) y nunca sale del dispositivo.
//  Ni el administrador de Supabase ni nadie con acceso a la BD puede ver los montos.
//

import CryptoKit
import Foundation
import Security

/// Servicio de cifrado para montos de transacciones.
/// Usa AES-GCM con una clave de 256 bits almacenada en Keychain por usuario.
enum TransactionEncryptionService {
    private static let keychainService = "com.financeflow.transaction_encryption"
    private static let keySize = 32

    /// Obtiene o genera la clave de cifrado para el usuario actual.
    /// La clave se almacena en Keychain y está ligada al user_id.
    static func getOrCreateKey(userId: UUID) throws -> SymmetricKey {
        let account = userId.uuidString
        if let existing = loadKey(account: account) {
            return existing
        }
        let newKey = SymmetricKey(size: .bits256)
        try saveKey(newKey, account: account)
        return newKey
    }

    /// Cifra un monto (Decimal) y devuelve la representación en base64.
    static func encrypt(amount: Decimal, userId: UUID) throws -> String {
        let key = try getOrCreateKey(userId: userId)
        let plaintext = "\(amount)"
        guard let data = plaintext.data(using: .utf8) else {
            throw EncryptionError.encodingFailed
        }
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            throw EncryptionError.sealFailed
        }
        return combined.base64EncodedString()
    }

    /// Descifra una cadena base64 y devuelve el Decimal.
    static func decrypt(encryptedBase64: String, userId: UUID) throws -> Decimal {
        let key = try getOrCreateKey(userId: userId)
        guard let combined = Data(base64Encoded: encryptedBase64) else {
            throw EncryptionError.invalidBase64
        }
        let sealedBox = try AES.GCM.SealedBox(combined: combined)
        let decrypted = try AES.GCM.open(sealedBox, using: key)
        guard let plaintext = String(data: decrypted, encoding: .utf8) else {
            throw EncryptionError.decodingFailed
        }
        guard let decimal = Decimal(string: plaintext) else {
            throw EncryptionError.invalidDecimal(plaintext)
        }
        return decimal
    }

    /// Elimina la clave del usuario (ej. al cerrar sesión, para que otro usuario no herede datos).
    /// Opcional: si quieres que al cambiar de usuario se borre la clave del anterior.
    static func deleteKey(userId: UUID) {
        let account = userId.uuidString
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Keychain

    private static func loadKey(account: String) -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              data.count == keySize else {
            return nil
        }
        return SymmetricKey(data: data)
    }

    private static func saveKey(_ key: SymmetricKey, account: String) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            throw EncryptionError.keychainSaveFailed(status)
        }
    }
}

enum EncryptionError: LocalizedError {
    case encodingFailed
    case sealFailed
    case invalidBase64
    case decodingFailed
    case invalidDecimal(String)
    case keychainSaveFailed(OSStatus)
    case noSession

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Error al codificar el monto."
        case .sealFailed: return "Error al cifrar."
        case .invalidBase64: return "Datos cifrados inválidos."
        case .decodingFailed: return "Error al decodificar el monto."
        case .invalidDecimal(let s): return "Monto inválido: \(s)"
        case .keychainSaveFailed(let s): return "Error al guardar la clave (Keychain: \(s))."
        case .noSession: return "No hay sesión activa para cifrar."
        }
    }
}
