//
//  SettingsViewController.swift
//  CodeComplete
//
//  Copyright © 2020 Vijay Sharma. All rights reserved.
//

import UIKit

public enum SettingsType: String {
	case contactUs = "Contact Us"
	case restorePurchase = "Restore Purchases"
	case termsOfService = "Terms of Service"
	case privacyPolicy = "Privacy Policy"
	case personalize = "Personalize"
	case review = "Rate Us"
	case feedback = "Give Feedback"
	case onboard = "Welcome Screen"
	case empty = ""
	case secret = " "
}

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
	private lazy var tableView: UITableView = {[unowned self] in
		let view = UITableView()
		view.translatesAutoresizingMaskIntoConstraints = false
		view.backgroundColor = nil
		view.register(UITableViewCell.self, forCellReuseIdentifier: "settingsCell")
		view.dataSource = self
		view.delegate = self
			
		return view
	}()
	
	private let items = [
		SettingsType.onboard,
		.contactUs,
		.termsOfService,
		.privacyPolicy,
		.restorePurchase,
		.feedback,
		.review
	]
	private let service: Service
	private let database: Database
	
	var delegate: (() -> Void)?
	init(
		service: Service,
		database: Database
	) {
		self.service = service
		self.database = database
		super.init(nibName: nil, bundle: nil)
		title = "Settings"
		
		view.backgroundColor = CodeComplete.theme.primary
		view.addSubview(tableView)
		NSLayoutConstraint.activate([
			tableView.topAnchor.constraint(equalTo: view.topAnchor),
			tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
		])
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		items.count
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "settingsCell", for: indexPath)
		cell.backgroundColor = nil
		cell.textLabel?.text = items[indexPath.row].rawValue
		cell.textLabel?.textColor = .white
		
		return cell
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		
		let selection = items[indexPath.row]
		switch selection {
		case .contactUs:
			if let url = URL(string: "https://vijaysharma.ca/code-complete/") {
				UIApplication.shared.open(url)
			}
			break
		case .restorePurchase:
			restorePurchase()
			break
		case .privacyPolicy:
			if let url = URL(string: "https://vijaysharma.ca/code-complete-privacy/") {
				UIApplication.shared.open(url)
			}
			break
		case .termsOfService:
			if let url = URL(string: "https://vijaysharma.ca/code-complete-tos/") {
				UIApplication.shared.open(url)
			}
			break
		case .review:
			if let url = URL(string: "itms-apps://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=1518395948&onlyLatestVersion=true&pageNumber=0&sortOrdering=1&type=Purple+Software") {
				UIApplication.shared.open(url)
			}
			break
		case .feedback:
			TestFairy.showFeedbackForm("5b3af35e59a1e074e2d50675b1b629306cf0cfbd", takeScreenshot: false)
			break
		case .onboard:
			let controller = OnboardingViewController()
			controller.delegate = {
				$0.dismiss(animated: true)
			}
			self.present(controller, animated: true)
			break
		default:
			break
		}
	}
	
	private func restorePurchase() {
		service.restore { (success, error) in
			if let error = error {
				print("\(error.localizedDescription)")
				self.alert(
					title: "Trolls Strike again!",
					message: "Looks like there was a problem trying restore your purchase. We're sorry for the inconvenience Please try again later."
				)
			} else {
				let title = success ? "You're in!" : "Trolls Strike again!"
				let message = success ? "You now have access to all questions. Thank you for your support!" : "Oops! Looks like there was a problem processing your request. We're sorry for the inconvenience Please try again later."
				self.alert(
					title: title,
					message: message
				) { action in
					self.navigationController?.popViewController(animated: true)
				}
			}
		}
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		guard self.isMovingFromParent else { return }
		self.delegate?()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
