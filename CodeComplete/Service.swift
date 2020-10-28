//
//  Service.swift
//  CodeComplete
//
//  Copyright © 2020 Vijay Sharma. All rights reserved.
//

import Foundation
import Purchases

class Service {
	private let free: [String]
	let purchase: PurchaseService
	
	init(purchase: PurchaseService, free: [String]) {
		self.free = free
		self.purchase = purchase
	}

	func isLocked(name: String, callback: @escaping (Bool) -> Void) {
		if free.contains(name) {
			callback(false)
			return
		}

		purchase.isActive(subscription: "all_problem_access") { isActive in
			#if DEBUG
//			callback(false)
			callback(!isActive)
			#else
			callback(!isActive)
			#endif
		}
	}
	
	func puchase(package: Purchases.Package,  _ completion: @escaping (Bool, Error?) -> Void) {
		purchase.purchase(package: package, subscription: "all_problem_access", completion: completion)
	}
	
	func restore( _ completion: @escaping (Bool, Error?) -> Void) {
		purchase.restore(subscription: "all_problem_access", completion)
	}
}
