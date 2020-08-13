//
//  QuestionViewController.swift
//  CodeComplete
//
//  Copyright © 2020 Vijay Sharma. All rights reserved.
//

import UIKit
import Sourceful
import Highlightr
import Purchases
import FBSDKCoreKit
import Firebase

class QuestionProvider {
	private let model: QuestionsViewModel
	private var section: Int
	private var index: Int
	private var _current: Question? = nil
	
	init(model: QuestionsViewModel, section: Int, index: Int) {
		self.model = model
		self.section = section
		self.index = index
	}
	
	func current() -> Question {
		return _current!
	}
	
	func next() -> Question {
		let item = model.get(section: section, index: index)
		let name = item.Name.lowercased().replacingOccurrences(of: " ", with: "-")
		
		let url = Bundle.main.url(forResource: name, withExtension: "json")!
		let data = try! Data(contentsOf: url)
		let json = try! JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
		let question = Question(data: json)
		
		let itemCount = model.itemCount(section)
		if (index + 1) < itemCount {
			index += 1
		} else {
			section = (section + 1) % model.sectionCount
			index = 0
		}
		
		Analytics.logEvent(AnalyticsEventSelectContent, parameters: [
			AnalyticsParameterItemID: "\(name)",
			AnalyticsParameterItemName: "\(question.Summary.Name)",
			AnalyticsParameterContentType: "question"
		])
		
		_current = question
		return question
	}
}

class QuestionViewController: UIViewController {
	private let highlightr: Highlightr? = {
		let h = Highlightr()
		h?.setTheme(to: CodeComplete.theme.highlightr)
		h?.theme.codeFont = SourceCodeDarkTheme.codeFont
		return h
	}()
	private let json = JSONPrettyPrinter()
	
	private let provider: QuestionProvider
	private let service: Service
	private let database: Database
	
	private var panel: (View & QuestionView)? = nil
	private let locked = LockedView()
	private let timer = QuestionTimer()
	private var timerBottomConstraint: NSLayoutConstraint? = nil
	
	private let lexer = JavaScriptLexer()
	private let theme = CodeComplete.theme
//	private let engine = CodeEngine()
	
	private let javascript = JavaScriptSyntax()
	private var hidden: [Bool] = []
	
	private var sizeButtton: UIBarButtonItem!
	
	private var changes: [String] = []
	var delegate: (([String]) -> Void)?
	
	init(
		provider: QuestionProvider,
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
		
		let question = provider.next()
		self.show(question: question)
		
		NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
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
			if self.timer.isActive() {
				self.timer.stop()
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
	
	private func show(question: Question) {
		service.isLocked(name: question.Summary.Name) { isLocked in
			self.buildView(question: question, locked: isLocked)
		}
	}
	
	private func buildView(question: Question, locked isLocked: Bool) {
		view.subviews.forEach { $0.removeFromSuperview() }
		
		title = question.Summary.Name
		view.backgroundColor = theme.primary
		navigationItem.largeTitleDisplayMode = .never
		hidden = [Bool](repeating: true, count: question.JSONTests.count)
		
		let padding = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
		
		let promptView = PromptView(question: question, state: database.state(name: question.Summary.Name))
		let console = ConsoleView(message: "Run your code when you're ready.")
		let consolePanel = GenericPanel(cellName: "Console", tabName: "Console", content: console)
		let testView = TestsView(question: question, json: json, highlightr: highlightr)
		testView.revealed = { self.hidden[$0].toggle() }
		let testPanel = TestsPanel(view: testView)
		let codePanel = CodePanel(
			question: question,
			lexer: lexer,
			database: database
		)
		codePanel.run = {
			Analytics.logEvent(AnalyticsEventSelectContent, parameters: [
				AnalyticsParameterItemID: "runYourSolution",
				AnalyticsParameterItemName: "Run Your Solution",
				AnalyticsParameterContentType: "action"
			])
			
			codePanel.set(enabled: false)
			// TODO: Need to find out why when code engine is a property
			// TODO: of the class, changes to the code don't seem to give
			// TODO: Different results
			let engine = CodeEngine()
			engine.run(code: $0, question: question) { results in
				codePanel.set(enabled: true)
				switch results {
				case .success(let result):
					self.showTest(
						question: question,
						result: result,
						prompt: promptView,
						console: console,
						testPanel: testPanel,
						showActual: true
					)
					self.panel?.showPanel(panel: testPanel)
					break;
				case .failure(let error):
					self.showConsole(error: error, console: console)
					self.panel?.showPanel(panel: consolePanel)
					break;
				}
				
			}
		}
		codePanel.restore = {
			Analytics.logEvent(AnalyticsEventSelectContent, parameters: [
				AnalyticsParameterItemID: "restore",
				AnalyticsParameterItemName: "Restore Code",
				AnalyticsParameterContentType: "action"
			])
			self.confirm(title: "Restore Default Code", message: "You're about to reset your solution. Any work you've done on this solution will be lost.\nAre you sure you want to continue?") { _ in
				codePanel.setCurrent(code: question.Resources.javascript.StartingCode)
			}
		}
		
		let testDebugPanel = CodeEditor()
		testDebugPanel.delegate = javascript
		testDebugPanel.theme = theme.sourceCode
		testDebugPanel.contentTextView.isEditable = true
		testDebugPanel.text = question.Resources.javascript.StartingTest

		let sandboxTestPanel = CodeEditor()
		sandboxTestPanel.delegate = javascript
		sandboxTestPanel.theme = theme.sourceCode
		sandboxTestPanel.contentTextView.isEditable = true
		sandboxTestPanel.text = question.Resources.javascript.SandboxCode

		let solutions = SolutionsPanel(question: question, lexer: javascript)
		solutions.run = {
			Analytics.logEvent(AnalyticsEventSelectContent, parameters: [
				AnalyticsParameterItemID: "runourSolution",
				AnalyticsParameterItemName: "Run Our Solution",
				AnalyticsParameterContentType: "action"
			])
			solutions.set(enabled: false)
			// TODO: Need to find out why when code engine is a property
			// TODO: of the class, changes to the code don't seem to give
			// TODO: Different results
			let engine = CodeEngine()
			engine.run(code: $0, question: question) { results in
				solutions.set(enabled: true)

				switch results {
				case .success(let result):
					self.showTest(
						question: question,
						result: result,
						prompt: promptView,
						console: console,
						testPanel: testPanel,
						showActual: false
					)
					self.panel?.showPanel(panel: testPanel)
					break;
				case .failure(let error):
					self.showConsole(error: error, console: console)
					self.panel?.showPanel(panel: consolePanel)
					break;
				}
			}
		}
		
		solutions.copy = { code in
			Analytics.logEvent(AnalyticsEventSelectContent, parameters: [
				AnalyticsParameterItemID: "copy",
				AnalyticsParameterItemName: "Copy solution",
				AnalyticsParameterContentType: "action"
			])
			self.confirm(title: "Copy Solution", message: "You're about to copy our soltion into your solution. Any work you've done on this solution will be lost.\nAre you sure you want to continue?") { _ in
				codePanel.setCurrent(code: code)
			}
		}
		
		if (!database.fullScreen) {
			var rightPanels: [QuestionPanelDelegate] = [
				codePanel,
				solutions,
				consolePanel,
			]
			#if DEBUG
			rightPanels.append(GenericPanel(cellName: "Debug Tests", tabName: "Tests", content: testDebugPanel))
			rightPanels.append(GenericPanel(cellName: "Sandbox Test", tabName: "Sandbox Test", content: sandboxTestPanel))
			#endif
			
			let leftPanels: [QuestionPanelDelegate] = [
				GenericPanel(cellName: "Prpmpt", tabName: "Prompt", content: promptView, padding: padding),
				GenericPanel(cellName: "Hints", tabName: "Hints", content: HintsView(question: question), padding: padding),
				testPanel
			]
			
			self.panel = SplitPanel(leftPanels: leftPanels, rightPanels: rightPanels)
		} else {
			var panels = [
				GenericPanel(cellName: "Prompts", tabName: "Prompt", content: promptView, padding: padding),
				codePanel,
				GenericPanel(cellName: "Hints", tabName: "Hints", content: HintsView(question: question), padding: padding),
				testPanel,
				solutions,
				consolePanel,
			]
			#if DEBUG
			panels.append(GenericPanel(cellName: "Dedbug Tests", tabName: "Tests", content: testDebugPanel))
			panels.append(GenericPanel(cellName: "Sandbox Test", tabName: "Sandbox Test", content: sandboxTestPanel))
			#endif
			self.panel = SinglePanel(panels: panels)
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
		
		timerBottomConstraint = timer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 50)
		NSLayoutConstraint.activate([
			panel!.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
			panel!.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
			panel!.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
			panel!.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
			
			timer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
			timerBottomConstraint!,
			timer.heightAnchor.constraint(equalToConstant: 18),
			timer.widthAnchor.constraint(equalToConstant: 60),
		])
	}
	
	private func purchase(package: Purchases.Package, question: Question) {
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
	
	private func restore(question: Question) {
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
	
	private func checkPurchase(success: Bool, error: Error?, question: Question, package: Purchases.Package?) {
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
					self.changes.append(question.Summary.Name)
					self.buildView(question: question, locked: false)
				}
			}
		}
	}
	
	private func showTest(
		question: Question,
		result: TestResults,
		prompt: PromptView,
		console: ConsoleView,
		testPanel: TestsPanel,
		showActual: Bool
	) {
		let success = result.tests.first { !$0.success } == nil
		console.set(text: result.logs.joined(separator: "\n\n"), success: success)
		let view = ResultsView(
			question: question,
			results: result.tests,
			hidden: hidden,
			json: json,
			highlightr: highlightr,
			success: success,
			showActual: showActual
		)
		view.revealed = { self.hidden[$0].toggle() }
		testPanel.set(results: view)
		if showActual {
			let state = success ? "success" : "fail"
			database.set(state: state, name: question.Summary.Name)
			prompt.set(state: state)
			changes.append(question.Summary.Name)
		}
	}
	
	private func showConsole(error: EngineError, console: ConsoleView) {
		switch error {
		case .unknown:
			console.set(text: "Unknown failure", success: false)
			break
		case .internalError(let reason):
			console.set(text: reason, success: false)
			break
		case .engineCreationException:
			console.set(text: "Code execution engine creation error", success: false)
			break
		case .executionException(let reason):
			console.set(text: reason ?? "Code execution error", success: false)
			break
		case .timeout:
			console.set(text: "Code execution timed out", success: false)
			break
		}
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class CodePanel: GenericPanel, SyntaxTextViewDelegate {
	private let name: String
	private let database: Database
	private let code: MultipleCodeEditors
	private let reset = ImageButton(systemIcon: "gobackward", padding: UIEdgeInsets(top: 11, left: 4, bottom: 11, right: 4))
	private let button = ActionImageButton(systemIcon: "play.fill", padding: UIEdgeInsets(top: 13, left: 4, bottom: 13, right: 4))
	private let lexer: JavaScriptLexer
	
	var run: ((String) -> Void)?
	var restore: (() -> Void)?
	
	init(
		question: Question,
		lexer: JavaScriptLexer,
		database: Database
	) {
		self.database = database
		self.lexer = lexer
		let startingCode = question.Resources.javascript.StartingCode
		name = question.Summary.Name
		code = MultipleCodeEditors(3)
		code.set(text: database.solution(name: name, index: 0) ?? startingCode, at: 0)
		code.set(text: database.solution(name: name, index: 1) ?? startingCode, at: 1)
		code.set(text: database.solution(name: name, index: 2) ?? startingCode, at: 2)
		code.set(edittable: true)
		code.set(theme: CodeComplete.theme.sourceCode)
		
		super.init(cellName: "Your Solutions", tabName: "Your Solutions", content: code)
		code.set(delegate: self)
		
		button.action = {
			self.run?(self.code.getCurrentText())
		}
		
		reset.action = {
			self.restore?()
		}
		
		code.actions.contentView.addArrangedSubview(button)
		code.actions.contentView.addArrangedSubview(reset)
	}
	
	func setCurrent(code: String) {
		self.code.setCurrent(text: code)
	}
	
	func didChangeText(_ syntaxTextView: SyntaxTextView) {
		guard let editor = syntaxTextView as? CodeEditor else { return }
		guard let index = code.index(of: editor) else { return }
		database.set(solution: syntaxTextView.contentTextView.text, name: name, index: index)
	}
	
	func lexerForSource(_ source: String) -> Lexer {
		lexer
	}
	
	func set(enabled: Bool) {
		button.set(enabled: enabled)
	}
}

class SolutionsPanel: GenericPanel {
	private let code: MultipleCodeEditors
	private let copyButton = ImageButton(systemIcon: "doc.on.doc", padding: UIEdgeInsets(top: 10, left: 4, bottom: 10, right: 4))
	private let button = ActionImageButton(systemIcon: "play.fill", padding: UIEdgeInsets(top: 13, left: 4, bottom: 13, right: 4))
	var run: ((String) -> Void)?
	var copy: ((String) -> Void)?
	
	init(question: Question, lexer: SyntaxTextViewDelegate) {
		code = MultipleCodeEditors(question.Resources.javascript.Solutions.count)
		code.set(delegate: lexer)
		code.set(edittable: false)
		code.set(theme: CodeComplete.theme.sourceCode)
		super.init(cellName: "Our Solutions", tabName: "Our Solutions", content: BlurredView(content: code, tip: "Tap to reveal solutions"))
		
		question.Resources.javascript.Solutions.enumerated().forEach {
			self.code.set(text: $0.element, at: $0.offset)
		}
		
		button.action = {
			let solution = question.Resources.javascript.Solutions[self.code.getCurrent()]
			self.run?(solution)
		}
		
		copyButton.action = {
			let solution = question.Resources.javascript.Solutions[self.code.getCurrent()]
			self.copy?(solution)
		}
		
		code.actions.contentView.addArrangedSubview(button)
		code.actions.contentView.addArrangedSubview(copyButton)
	}
	
	func set(enabled: Bool) {
		button.set(enabled: enabled)
	}
}

class TestsPanel: GenericPanel {
	private var current: UIView
	
	init(view: TestsView) {
		self.current = view
		super.init(cellName: "Tests", tabName: "Tests")
	}
	
	func set(results: ResultsView) {
		current = results
	}
	
	override func configure(panel: QuestionPanel, tab: Int, content: View) {
		content.addSubview(current)
		content.fill(with: current)
	}
}
