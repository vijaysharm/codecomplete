//
//  Database.swift
//  CodeComplete
//
//  Copyright © 2020 Vijay Sharma. All rights reserved.
//

import Foundation
import SwiftKeychainWrapper

class Database {
	static let `default` = Database()
	private lazy var keystore = KeychainWrapper.standard
	
	var fullScreen: Bool {
		get {
			keystore.bool(forKey: "fullScreen") ?? false
		}
		set {
			keystore.set(newValue, forKey: "fullScreen")
		}
	}
	
	func set(solution: String, name: String, index: Int) {
		let clean = name.lowercased().replacingOccurrences(of: " ", with: "-")
		keystore.set(solution, forKey: "solution-\(clean)-\(index)")
	}
	
	func solution(name: String, index: Int) -> String? {
		let clean = name.lowercased().replacingOccurrences(of: " ", with: "-")
		return keystore.string(forKey: "solution-\(clean)-\(index)")
	}
	
	func set(state: String, name: String) {
		let clean = name.lowercased().replacingOccurrences(of: " ", with: "-")
		keystore.set(state, forKey: "state-\(clean)")
	}
	
	func state(name: String) -> String? {
		let clean = name.lowercased().replacingOccurrences(of: " ", with: "-")
		return keystore.string(forKey: "state-\(clean)")
	}
}
