//
//  PurchaseService.swift
//  CodeComplete
//
//  Copyright © 2020 Vijay Sharma. All rights reserved.
//

import Foundation
import Purchases

enum PurchaseError: Error {
	case invalidPurchase
	case purchasingNotEnabled
}

class PurchaseService: NSObject {
	private let purchaseId: String
	private lazy var purchase: Purchases = {[unowned self] in
		Purchases.debugLogsEnabled = true
		Purchases.configure(withAPIKey: self.purchaseId)
		return Purchases.shared
	}()
	
	init(purchaseId: String) {
		self.purchaseId = purchaseId
		super.init()
	}
	
	func isActive(subscription: String, _ completion: @escaping (Bool) -> Void) {
		purchase.purchaserInfo { (purchaserInfo, error) in
			if let _ = error {
				completion(false)
			} else {
				let active = purchaserInfo?.isActive(subscription: subscription) ?? false
				completion(active)
			}
		}
	}
	
	func package(_ completion: @escaping (Purchases.Offerings?, Error?) -> Void) {
		purchase.offerings {
			completion($0, $1)
		}
	}
	
	func purchase(
		package: Purchases.Package,
		subscription: String,
		completion: @escaping (Bool, Error?) -> Void
	) {
		guard Purchases.canMakePayments() else {
			completion(false, PurchaseError.purchasingNotEnabled)
			return
		}
		
		purchase.purchasePackage(package) { (_, purchaserInfo, error, _) in
			let isActive = purchaserInfo?.isActive(subscription: subscription) ?? false
			completion(isActive, error)
		}
	}
	
	func restore(subscription: String, _ completion: @escaping (Bool, Error?) -> Void) {
		purchase.restoreTransactions { (purchaserInfo, error) in
			if let error = error {
				completion(false, error)
			} else {
				let isActive = purchaserInfo?.isActive(subscription: subscription) ?? false
				completion(isActive, nil)
			}
		}
	}
}

extension Purchases.PurchaserInfo {
	func isActive(subscription: String) -> Bool {
		return entitlements[subscription]?.isActive == true
	}
}
