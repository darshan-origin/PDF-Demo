//
//  ThreadManager.swift
//  PDF Tools
//
//  Created by mac on 17/02/26.
//

import Foundation

struct ThreadManager {
    static let shared = ThreadManager()
    
    /// Perform task on Background Thread
    func background(_ block: @escaping () -> Void) {
        DispatchQueue.global(qos: .background).async {
            block()
        }
    }
    
    /// Perform task Background Thread but as uing qos of userInitiated
    func backgroundUserInitiated(_ block: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            block()
        }
    }
    
    /// Perform task on Main Thread (UI updates)
    func main(_ block: @escaping () -> Void) {
        DispatchQueue.main.async {
            block()
        }
    }
}
