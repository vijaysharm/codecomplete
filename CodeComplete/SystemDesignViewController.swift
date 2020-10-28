//
//  SystemDesignViewController.swift
//  CodeComplete
//
//  Created by Vijay Sharma on 2020-09-23.
//  Copyright © 2020 Vijay Sharma. All rights reserved.
//

import UIKit
import Sourceful
import Highlightr
import Purchases
import FBSDKCoreKit
import Firebase

class DesignProvider {
	private let questions: [SystemDesignQuestion]
	private var index: Int
	private var _current: SystemDesignQuestion? = nil
	
	init(model: [SystemDesignQuestion], index: Int) {
		self.questions = model
		self.index = index
	}
	
	func current() -> SystemDesignQuestion {
		return _current!
	}
	
	func next() -> SystemDesignQuestion {
		let item = questions[index]
		let name = item.name.lowercased().replacingOccurrences(of: " ", with: "-")
		let question = item
		
		let itemCount = questions.count
		if (index + 1) < itemCount {
			index += 1
		} else {
			index = 0
		}
		
		Analytics.logEvent(AnalyticsEventSelectContent, parameters: [
			AnalyticsParameterItemID: "\(name)",
			AnalyticsParameterItemName: "\(question.name)",
			AnalyticsParameterContentType: "question"
		])
		
		_current = question
		return question
	}
}

class SystemDesignViewController: UIViewController {
	private let provider: DesignProvider
	private let service: Service
	private let database: Database
	
	private var panel: (View & QuestionView)? = nil
	private let locked = LockedView()
	private let timer = QuestionTimer()
	private var timerBottomConstraint: NSLayoutConstraint? = nil
	
	private let theme = CodeComplete.theme
	
	private var hidden: [Bool] = []
	
	private var sizeButtton: UIBarButtonItem!
	
	private var changes: [String] = []
	var delegate: (([String]) -> Void)?
	
	init(
		provider: DesignProvider,
		service: Service,
		database: Database
	) {
		self.provider = provider
		self.database = database
		self.service = service
		super.init(nibName: nil, bundle: nil)
		
		let nextQuestionButton = UIBarButtonItem(image: UIImage(systemName: "arrow.right"), style: .plain, target: self, action: #selector(nextQuestion))
		nextQuestionButton.tintColor = CodeComplete.theme.textPrimary
		sizeButtton = UIBarButtonItem(
			image: UIImage(systemName: database.fullScreen ? "uiwindow.split.2x1" : "macwindow"),
			style: .plain,
			target: self,
			action: #selector(resize)
		)
		sizeButtton.tintColor = CodeComplete.theme.textPrimary
		let overflowButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), style: .plain, target: self, action: #selector(displayActionSheet))
		overflowButton.tintColor = CodeComplete.theme.textPrimary
		
		navigationItem.rightBarButtonItems = [overflowButton, nextQuestionButton, sizeButtton]
		
		timer.stopButton.action =  {
			self.setTimerState(hide: true)
		}
		
		let question = provider.next()
		self.show(question: question)
		
//		NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
//		NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		timer.stop()
		guard self.isMovingFromParent else { return }
		self.delegate?(changes)
	}
		
	@objc func keyboardWillShow(notification: NSNotification) {
		guard let info = notification.userInfo else { return }
		guard let keyboardFrameValue = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
		
		let bounds = view.frame
		self.view.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.size.height - keyboardFrameValue.size.height)
		self.view.layoutIfNeeded()
	}
	
	@objc func keyboardWillHide(notification: NSNotification) {
		let bounds = UIScreen.main.bounds
		self.view.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.size.height)
		self.view.layoutIfNeeded()
	}
	
	@objc func nextQuestion() {
		Analytics.logEvent(AnalyticsEventSelectContent, parameters: [
			AnalyticsParameterItemID: "nextQuestion",
			AnalyticsParameterItemName: "Next Question",
			AnalyticsParameterContentType: "action"
		])
		let question = provider.next()
		self.show(question: question)
	}
	
	@objc func resize() {
		Analytics.logEvent(AnalyticsEventSelectContent, parameters: [
			AnalyticsParameterItemID: "resize",
			AnalyticsParameterItemName: "Resize Screen",
			AnalyticsParameterContentType: "action"
		])
		database.fullScreen.toggle()
		sizeButtton.image = UIImage(systemName: database.fullScreen ? "uiwindow.split.2x1" : "macwindow")
		self.show(question: provider.current())
	}
	
	@IBAction func displayActionSheet(_ sender: Any) {
		let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

		let timerAction = UIAlertAction(title: timer.isActive() ? "Stop Timer" : "Start Timer", style: .default) { _ in
			self.setTimerState(hide: false)
		}
		
		let feedbackAction = UIAlertAction(title: "Give Feedback", style: .default) { _ in
			TestFairy.showFeedbackForm("5b3af35e59a1e074e2d50675b1b629306cf0cfbd", takeScreenshot: true)
		}
		let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

		optionMenu.addAction(timerAction)
		optionMenu.addAction(feedbackAction)
		optionMenu.addAction(cancelAction)
		optionMenu.popoverPresentationController?.barButtonItem = sender as? UIBarButtonItem;
		
		Analytics.logEvent(AnalyticsEventSelectContent, parameters: [
			AnalyticsParameterItemID: "overflow",
			AnalyticsParameterItemName: "Overflow Opttions",
			AnalyticsParameterContentType: "action"
		])
		self.present(optionMenu, animated: true, completion: nil)
	}
	
	private func setTimerState(hide: Bool) {
		if self.timer.isActive() {
			self.timer.stop()
			if hide { self.timerBottomConstraint?.constant = (self.view.frame.height + 100) }
		} else {
			self.timerBottomConstraint?.constant = -8
			self.timer.start()
			Analytics.logEvent(AnalyticsEventSelectContent, parameters: [
				AnalyticsParameterItemID: "timerStart",
				AnalyticsParameterItemName: "Start Timer",
				AnalyticsParameterContentType: "action"
			])
		}
	}
	
	private func show(question: SystemDesignQuestion) {
		service.isLocked(name: question.name) { isLocked in
			self.buildView(question: question, locked: isLocked)
		}
	}
	
	private func buildView(question: SystemDesignQuestion, locked isLocked: Bool) {
		view.subviews.forEach { $0.removeFromSuperview() }
		
		title = question.name
		view.backgroundColor = theme.primary
		navigationItem.largeTitleDisplayMode = .never
		hidden = [Bool](repeating: true, count: question.walkthrough.count)
		
		let padding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
				
		if (database.fullScreen) {
			let panels = [
				GenericPanel(cellName: "Prompt", tabName: "Prompt", content: SystemDesignPrompt(question: question, state: database.state(name: question.name)), padding: padding),
				GenericPanel(cellName: "Your Solution", tabName: "Your Solution", content: DesignSolutionView(question: question, database: database), padding: padding),
				GenericPanel(cellName: "Questions", tabName: "Questions", content: DesignClarifyingQuestionsView(question: question), padding: padding),
				GenericPanel(cellName: "Walkthrough", tabName: "Walkthrough", content: DesignWalkthroughView(question: question), padding: padding),
			]
			self.panel = SinglePanel(panels: panels)
		} else {
			self.panel = SplitPanel(
				leftPanels: [
					GenericPanel(cellName: "Prompt", tabName: "Prompt", content: SystemDesignPrompt(question: question, state: database.state(name: question.name)), padding: padding),
					GenericPanel(cellName: "Questions", tabName: "Questions", content: DesignClarifyingQuestionsView(question: question), padding: padding),
					GenericPanel(cellName: "Walkthrough", tabName: "Walkthrough", content: DesignWalkthroughView(question: question), padding: padding)
				],
				rightPanels: [
					GenericPanel(cellName: "Your Solution", tabName: "Your Solution", content: DesignSolutionView(question: question, database: database), padding: padding),
				]
			)
		}
		
		view.addSubview(panel!)
		view.addSubview(timer)
		
		if isLocked {
			view.addSubview(locked)
			NSLayoutConstraint.activate([
				locked.topAnchor.constraint(equalTo: view.topAnchor),
				locked.bottomAnchor.constraint(equalTo: view.bottomAnchor),
				locked.leadingAnchor.constraint(equalTo: view.leadingAnchor),
				locked.trailingAnchor.constraint(equalTo: view.trailingAnchor)
			])
			
			service.purchase.package { (offerings, error) in
				guard error == nil else { return }
				guard let offerings = offerings, let current = offerings.current else { return }
				let view = PurchaseView(offer: current)
				view.purchase = { package in
					self.purchase(package: package, question: question)
				}
				view.restore = {
					self.restore(question: question)
				}
				let minHeight = max(320, UIScreen.main.bounds.height * 0.45)
				let minWidth = max(420, UIScreen.main.bounds.width * 0.45)
				self.locked.set(dialog: view, size: CGSize(width: minWidth, height: minHeight))
			}
		}
		
		timerBottomConstraint = timer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 100)
		NSLayoutConstraint.activate([
			panel!.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
			panel!.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
			panel!.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
			panel!.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
			
			timer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
			timerBottomConstraint!,
		])
	}
	
	private func purchase(package: Purchases.Package, question: SystemDesignQuestion) {
		let spinner = UIActivityIndicatorView(style: .large)
		spinner.color = .white
		spinner.translatesAutoresizingMaskIntoConstraints = false
		spinner.startAnimating()
		self.locked.set(dialog: spinner, size: CGSize(width: 48, height: 48))
		service.puchase(package: package) { (success, error) in
			spinner.stopAnimating()
			self.checkPurchase(success: success, error: error, question: question, package: package)
		}
	}
	
	private func restore(question: SystemDesignQuestion) {
		let spinner = UIActivityIndicatorView(style: .large)
		spinner.color = .white
		spinner.translatesAutoresizingMaskIntoConstraints = false
		spinner.startAnimating()
		self.locked.set(dialog: spinner, size: CGSize(width: 48, height: 48))
		service.restore { (success, error) in
			spinner.stopAnimating()
			self.checkPurchase(success: success, error: error, question: question, package: nil)
		}
	}
	
	private func checkPurchase(success: Bool, error: Error?, question: SystemDesignQuestion, package: Purchases.Package?) {
		if let error = error {
			print("\(error.localizedDescription)")
			self.alert(
				title: "Trolls Strike again!",
				message: "Looks like there was a problem trying restore your purchase. We're sorry for the inconvenience Please try again later."
			) { _ in
				self.buildView(question: question, locked: true)
			}
		} else {
			let title = success ? "You're In!" : "Trolls Strike again!"
			let message = success ? "You now have access to all problems. Thank you for your support!" : "Oops! Looks like there was a problem processing your request. We're sorry for the inconvenience Please try again later."
			self.alert(
				title: title,
				message: message
			) { _ in
				if success {
					self.changes.append(question.name)
					self.buildView(question: question, locked: false)
				}
			}
		}
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class SystemDesignPrompt: View {
	class DesignWebView: WKWebView {
		init(question: SystemDesignQuestion, state: String?) {
			let config = WKWebViewConfiguration()
			super.init(frame: .zero, configuration: config)
			
			translatesAutoresizingMaskIntoConstraints = false
			isOpaque = false
			backgroundColor = CodeComplete.theme.tertiary
			
			let state = getStateClass(state: state);
			
			let html = """
			<!DOCTYPE html>
			<html lang="en">
				<head>
					<meta charset="utf-8">
					<meta name="viewport" content="initial-scale=1.0" />
					<style>\(CodeComplete.theme.css)</style>
				</head>

				<body>
					<div class="info">
						<span class="state \(state)"></span>
					</div>
					<div class="container">\(question.prompt)</div>
					<div class="container">
						<p><i>Many systems design questions are intentionally left very vague and are literally given in the form of "Design XYZ". It's your job to ask clarifying questions to better understand the system that you have to build.</i></p>
						<p><i>We've laid out some of these questions below; their answers should give you some guidance on the problem. Before looking at them, we encourage you to take few minutes to think about what questions you'd ask in a real interview.</i></p>
					</div>
				</body>
			</html>
			"""
			loadHTMLString(html, baseURL: nil)
		}
		
		func set(state: String?) {
			let state = getStateClass(state: state);
			evaluateJavaScript("document.querySelector('.state').className='state \(state)';", completionHandler: nil)
		}
		
		private func getStateClass(state: String?) -> String {
			if state == nil {
				return ""
			} else if state != nil && state! == "success" {
				return "success"
			} else if state != nil && state! == "fail" {
				return "fail"
			}
			return ""
		}
		
		required init?(coder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}
	}
	
	private let promptView: DesignWebView
	
	init(question: SystemDesignQuestion, state: String?) {
		promptView = DesignWebView(question: question, state: state)
		super.init()
		
		addSubview(promptView)
		fill(with: promptView)
	}
	
	func set(state: String?) {
		promptView.set(state: state)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class DesignWalkthroughView: UIScrollView {
	private let contentView: UIStackView = {
		let view = UIStackView()
		view.translatesAutoresizingMaskIntoConstraints = false
		view.axis = .vertical
		view.distribution = .fill
		view.alignment = .fill
		view.spacing = 16

		return view
	}()

	init(question: SystemDesignQuestion) {
		super.init(frame: .zero)
		translatesAutoresizingMaskIntoConstraints = false

		let hints = question.walkthrough
		for (_, hint) in hints.enumerated() {
			if let hintImage = hint.image, let image = UIImage(named: "\(hintImage.name).\(hintImage.extension)") {
				contentView.addArrangedSubview(
					HiddenSolutionImageView(title: hint.title, image: image)
				)
			} else {
				contentView.addArrangedSubview(
					HiddenSolutionTextView(title: hint.title, hint: hint.content)
				)
			}
		}

		addSubview(contentView)

		let contentLayoutGuide = self.contentLayoutGuide
		let frameLayoutGuide = self.frameLayoutGuide
		NSLayoutConstraint.activate([
			contentView.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
			contentView.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),
			contentView.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
			contentView.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
			contentView.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor)
		])
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class DesignClarifyingQuestionsView: UIScrollView {
	private let contentView: UIStackView = {
		let view = UIStackView()
		view.translatesAutoresizingMaskIntoConstraints = false
		view.axis = .vertical
		view.distribution = .fill
		view.alignment = .fill
		view.spacing = 16

		return view
	}()

	init(question: SystemDesignQuestion) {
		super.init(frame: .zero)
		translatesAutoresizingMaskIntoConstraints = false

		let hints = question.hints
		for (index, hint) in hints.enumerated() {
			contentView.addArrangedSubview(
				HiddenSolutionTextView(
					title: "Question \(index + 1)",
					hint: """
					<div class="container">
						<p><b><i>Q: \(hint.question)</i></b></p>
						<p>A: \(hint.answer)</p>
					</div>
					"""
				)
			)
		}

		addSubview(contentView)

		let contentLayoutGuide = self.contentLayoutGuide
		let frameLayoutGuide = self.frameLayoutGuide
		NSLayoutConstraint.activate([
			contentView.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
			contentView.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),
			contentView.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor),
			contentView.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
			contentView.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor)
		])
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class DesignSolutionView: View, SyntaxTextViewDelegate {
	class LexerStub: Lexer {
		func getSavannaTokens(input: String) -> [Token] { [] }
	}
	
	private let editor = CodeEditor()
	private let database: Database
	private let question: SystemDesignQuestion
	
	init(question: SystemDesignQuestion, database: Database) {
		self.database = database
		self.question = question
		super.init()
		
		editor.theme = CodeComplete.theme.sourceCode
		editor.contentTextView.isEditable = true
		editor.text = database.solution(name: question.name, index: 0) ?? ""
		editor.delegate = self
		
		addSubview(editor)
		fill(with: editor)
	}
	
	func didChangeText(_ syntaxTextView: SyntaxTextView) {
		database.set(state: "success", name: question.name)
		database.set(solution: syntaxTextView.text, name: question.name, index: 0)
	}
	
	func lexerForSource(_ source: String) -> Lexer {
		return LexerStub()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class HiddenSolutionTextView: View {
	init(title: String, hint: String) {
		super.init()

		layer.cornerRadius = 8
		clipsToBounds = true

		let titleLabel = Label(text: String(title))
		let titleView = View()
		titleView.addSubview(titleLabel)
		titleView.backgroundColor = CodeComplete.theme.secondary

		let hintLabel = HtmlView(content: hint)
		let hintLabelContainer = View()
		hintLabelContainer.backgroundColor = CodeComplete.theme.secondary
		hintLabelContainer.addSubview(hintLabel)
		hintLabelContainer.fill(with: hintLabel, padding: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8))
		
		let hintView = BlurredView(content: hintLabelContainer)

		addSubview(titleView)
		addSubview(hintView)

		NSLayoutConstraint.activate([
			titleLabel.topAnchor.constraint(equalTo: titleView.topAnchor),
			titleLabel.bottomAnchor.constraint(equalTo: titleView.bottomAnchor),
			titleLabel.leadingAnchor.constraint(equalTo: titleView.leadingAnchor, constant: 16),
			titleLabel.trailingAnchor.constraint(equalTo: titleView.trailingAnchor),

			titleView.topAnchor.constraint(equalTo: topAnchor),
			titleView.trailingAnchor.constraint(equalTo: trailingAnchor),
			titleView.leadingAnchor.constraint(equalTo: leadingAnchor),
			titleView.heightAnchor.constraint(equalToConstant: 48),

			hintView.topAnchor.constraint(equalTo: titleView.bottomAnchor),
			hintView.trailingAnchor.constraint(equalTo: trailingAnchor),
			hintView.leadingAnchor.constraint(equalTo: leadingAnchor),
			hintView.bottomAnchor.constraint(equalTo: bottomAnchor)
		])
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class HiddenSolutionImageView: View {
	init(title: String, image: UIImage) {
		super.init()

		layer.cornerRadius = 8
		clipsToBounds = true

		let titleLabel = Label(text: String(title))
		let titleView = View()
		titleView.addSubview(titleLabel)
		titleView.backgroundColor = CodeComplete.theme.secondary

		let hintImage = UIImageView(image: image)
		hintImage.translatesAutoresizingMaskIntoConstraints = false
		hintImage.contentMode = .scaleAspectFit
		
		let hintImageContainer = View()
		hintImageContainer.backgroundColor = CodeComplete.theme.secondary
		hintImageContainer.addSubview(hintImage)
		hintImageContainer.fill(with: hintImage, padding: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8))
		
		let hintView = BlurredView(content: hintImageContainer)

		addSubview(titleView)
		addSubview(hintView)

		NSLayoutConstraint.activate([
			titleLabel.topAnchor.constraint(equalTo: titleView.topAnchor),
			titleLabel.bottomAnchor.constraint(equalTo: titleView.bottomAnchor),
			titleLabel.leadingAnchor.constraint(equalTo: titleView.leadingAnchor, constant: 16),
			titleLabel.trailingAnchor.constraint(equalTo: titleView.trailingAnchor),

			titleView.topAnchor.constraint(equalTo: topAnchor),
			titleView.trailingAnchor.constraint(equalTo: trailingAnchor),
			titleView.leadingAnchor.constraint(equalTo: leadingAnchor),
			titleView.heightAnchor.constraint(equalToConstant: 48),

			hintView.topAnchor.constraint(equalTo: titleView.bottomAnchor),
			hintView.trailingAnchor.constraint(equalTo: trailingAnchor),
			hintView.leadingAnchor.constraint(equalTo: leadingAnchor),
			hintView.bottomAnchor.constraint(equalTo: bottomAnchor)
		])
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
