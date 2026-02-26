//
//  Untitled.swift
//  PDF Tools
//
//  Created by mac on 25/02/26.
//

import Foundation
import Security

final class PDFProtectionManager {
    
    static let shared = PDFProtectionManager()
    
    private let service = "com.yourapp.pdfprotection"
    
    // MARK: - Save Password
    
    func setPassword(_ password: String, for fileURL: URL) {
        let key = fileURL.lastPathComponent
        
        let data = Data(password.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    // MARK: - Get Password
    
    func getPassword(for fileURL: URL) -> String? {
        let key = fileURL.lastPathComponent
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    // MARK: - Remove Password
    
    func removePassword(for fileURL: URL) {
        let key = fileURL.lastPathComponent
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Check
    
    func isProtected(_ fileURL: URL) -> Bool {
        return getPassword(for: fileURL) != nil
    }
}
