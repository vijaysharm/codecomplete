//
//  OnboardViewController.swift
//  CodeComplete
//
//  Copyright © 2020 Vijay Sharma. All rights reserved.
//

import Foundation
import SwiftyOnboard

class OnboardingViewController: UIViewController, SwiftyOnboardDataSource {
	private let database: Database
	
	init(database: Database) {
		self.database = database
		super.init(nibName: nil, bundle: nil)
	}
	
	func swiftyOnboardNumberOfPages(_ swiftyOnboard: SwiftyOnboard) -> Int {
		1
	}
	
	func swiftyOnboardPageForIndex(_ swiftyOnboard: SwiftyOnboard, index: Int) -> SwiftyOnboardPage? {
		let page = SwiftyOnboardPage()
		return page
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
