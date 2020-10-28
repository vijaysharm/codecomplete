//
//  TabViewContrtoller.swift
//  CodeComplete
//
//  Copyright © 2020 Vijay Sharma. All rights reserved.
//

import UIKit

class TabViewContrtoller: UITabBarController {
	private let tech: ViewController
	private let settings: SettingsViewController
	private let design: SystemDesignListViewController
	
	private let database: Database
	
	init(
		techQuestions: ViewController,
		designQuestions: SystemDesignListViewController,
		settings: SettingsViewController,
		database: Database
	) {
		self.tech = techQuestions
		self.settings = settings
		self.design = designQuestions
		self.database = database
		super.init(nibName: nil, bundle: nil)
		
		let appearance = UITabBarAppearance()
		appearance.backgroundColor = CodeComplete.theme.primary
		setTabBarItemColors(appearance.stackedLayoutAppearance)
		setTabBarItemColors(appearance.inlineLayoutAppearance)
		setTabBarItemColors(appearance.compactInlineLayoutAppearance)
		self.tabBar.standardAppearance = appearance
		
		self.tech.tabBarItem = UITabBarItem(title: "Technical", image: UIImage(systemName: "chevron.left.slash.chevron.right"), tag: 0)
		self.design.tabBarItem = UITabBarItem(title: "System", image: UIImage(systemName: "globe"), tag: 1)
		self.settings.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gear"), tag: 2)
		
		self.viewControllers = [techQuestions, designQuestions, settings]
		self.title = "Code Complete"
	}
	
	override func viewDidAppear(_ animated: Bool) {
		if !database.onboarding {
			let controller = OnboardingViewController(skippable: false)
			controller.delegate = {
				self.database.onboarding = true
				$0.dismiss(animated: true)
			}
			self.present(controller, animated: true)
		}
	}
	
	override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
		if item.tag == 0 {
			self.tech.refresh()
		} else if item.tag == 1 {
			self.design.refresh()
		}
	}
	
	private func setTabBarItemColors(_ itemAppearance: UITabBarItemAppearance) {
		itemAppearance.normal.iconColor = CodeComplete.theme.textPrimary
		itemAppearance.normal.titleTextAttributes = [NSAttributedString.Key.foregroundColor: CodeComplete.theme.textPrimary]
		
		itemAppearance.selected.iconColor = CodeComplete.theme.action
		itemAppearance.selected.titleTextAttributes = [NSAttributedString.Key.foregroundColor: CodeComplete.theme.action]
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
