//
//  SceneDelegate.swift
//  CodeComplete
//
//  Copyright © 2020 Vijay Sharma. All rights reserved.
//

import UIKit
import Firebase
import FBSDKCoreKit

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

	var window: UIWindow?

	func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
		guard let windowScene = (scene as? UIWindowScene) else { return }
		let window = UIWindow(frame: windowScene.coordinateSpace.bounds)
		window.windowScene = windowScene

		Auth.auth().signInAnonymously() { (result, error) in
			if error != nil { Auth.auth().signInAnonymously() { (result, _) in
				if let result = result { DispatchQueue.main.async { TestFairy.setUserId(result.user.uid) } }
			} }
			else if let result = result { DispatchQueue.main.async { TestFairy.setUserId(result.user.uid) } }
		}
		
		let database = Database()
		let service = Service(
			purchase: PurchaseService(purchaseId: "wNaMDhfDzonBOOBnLJlPKQOuxphZUJEd"),
			free: [
				"Find Three Largest Numbers",
				"Binary Search",
				"Product Sum",
				"Nth Fibonacci",
				
				"Design A Code-Deployment System"
			]
		)
		
		let techQuestions = createQuestionsViewController(service: service, database: database)
		let designQuestions = createSystemDesignListViewController(service: service, database: database)
		let settings = createSettingsViewController(service: service, database: database)
		let tabs = TabViewContrtoller(
			techQuestions: techQuestions,
			designQuestions: designQuestions,
			settings: settings,
			database: database
		)
		
		let navigation = UINavigationController(rootViewController: tabs)
		navigation.navigationBar.prefersLargeTitles = false
		navigation.navigationBar.barTintColor = CodeComplete.theme.tertiary;
		navigation.navigationBar.tintColor = CodeComplete.theme.textPrimary;
		navigation.navigationBar.backgroundColor = CodeComplete.theme.tertiary
		navigation.navigationBar.isTranslucent = true;
		
		navigation.navigationBar.barStyle = .black
		navigation.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
		
		window.rootViewController = navigation
		window.makeKeyAndVisible()
		
		self.window = window
	}
	
	func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
		guard let url = URLContexts.first?.url else {
			return
		}

		ApplicationDelegate.shared.application(
			UIApplication.shared,
			open: url,
			sourceApplication: nil,
			annotation: [UIApplication.OpenURLOptionsKey.annotation]
		)
	}

	func sceneDidDisconnect(_ scene: UIScene) {
		// Called as the scene is being released by the system.
		// This occurs shortly after the scene enters the background, or when its session is discarded.
		// Release any resources associated with this scene that can be re-created the next time the scene connects.
		// The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
	}

	func sceneDidBecomeActive(_ scene: UIScene) {
		// Called when the scene has moved from an inactive state to an active state.
		// Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
	}

	func sceneWillResignActive(_ scene: UIScene) {
		// Called when the scene will move from an active state to an inactive state.
		// This may occur due to temporary interruptions (ex. an incoming phone call).
	}

	func sceneWillEnterForeground(_ scene: UIScene) {
		// Called as the scene transitions from the background to the foreground.
		// Use this method to undo the changes made on entering the background.
	}

	func sceneDidEnterBackground(_ scene: UIScene) {
		// Called as the scene transitions from the foreground to the background.
		// Use this method to save data, release shared resources, and store enough scene-specific state information
		// to restore the scene back to its current state.
	}

	private func createSettingsViewController(
		service: Service,
		database: Database
	) -> SettingsViewController {
//		let settingsButton = UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(settings))
//		settingsButton.tintColor = CodeComplete.theme.textPrimary
//		navigationItem.rightBarButtonItem = settingsButton
		
		let controller = SettingsViewController(service: service, database: database)
		controller.delegate = {}
		
		return controller
	}

	private func createQuestionsViewController(
		service: Service,
		database: Database
	) -> ViewController {
		let url = Bundle.main.url(forResource: "question-list", withExtension: "json")!
		let data = try! Data(contentsOf: url)
		let questions: QuestionList = try! JSONDecoder().decode(QuestionList.self, from: data)
		let viewController = ViewController(
			questions: questions.Problems.filter({ $0.Available }),
			service: service,
			database: database
		)
		
		return viewController
	}
	
	private func createSystemDesignListViewController(
		service: Service,
		database: Database
	) -> SystemDesignListViewController {
		let url = Bundle.main.url(forResource: "system-expert", withExtension: "json")!
		let data = try! Data(contentsOf: url)
		let questions: SystemDesignList = try! JSONDecoder().decode(SystemDesignList.self, from: data)
//		let questions: QuestionList = try! JSONDecoder().decode(QuestionList.self, from: data)
		let viewController = SystemDesignListViewController(
			questions: questions.design.filter({ $0.available }),
			service: service,
			database: database
		)
		
		return viewController
	}
}
