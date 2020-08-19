//
//  Views.swift
//  CodeComplete
//
//  Copyright © 2020 Vijay Sharma. All rights reserved.
//

import UIKit
import Sourceful
import Highlightr
import Purchases
import WebKit
import Firebase

class Label: UILabel {
	init(text: String = "") {
		super.init(frame: .zero)
		
		translatesAutoresizingMaskIntoConstraints = false
		textColor = CodeComplete.theme.textPrimary
		self.text = text
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class TextField: UITextView {
	init(text: String = "") {
		super.init(frame: .zero, textContainer: nil)
		translatesAutoresizingMaskIntoConstraints = false
		
		textColor = CodeComplete.theme.textPrimary
		self.text = text
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class ScrollView: UIScrollView {
	init(content: UIView, padding: UIEdgeInsets = .zero) {
		super.init(frame: .zero)
		translatesAutoresizingMaskIntoConstraints = false
		
		addSubview(content)
		
		let contentLayoutGuide = self.contentLayoutGuide
		let frameLayoutGuide = self.frameLayoutGuide
		NSLayoutConstraint.activate([
			content.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor, constant: padding.top),
			content.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor, constant: -padding.bottom),
			content.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor, constant: padding.left),
			content.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor, constant: -padding.right),
			content.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor, constant: -(padding.left + padding.right))
		])
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class HorizontalPageView: UICollectionView, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
	class PageViewCellView: UICollectionViewCell {
		override init(frame: CGRect) {
			super.init(frame: frame)
			translatesAutoresizingMaskIntoConstraints = false
		}
		
		func fill(view content: UIView) {
			subviews.forEach { $0.removeFromSuperview() }
			
			addSubview(content)
			NSLayoutConstraint.activate([
				content.topAnchor.constraint(equalTo: topAnchor),
				content.bottomAnchor.constraint(equalTo: bottomAnchor),
				content.leadingAnchor.constraint(equalTo: leadingAnchor),
				content.trailingAnchor.constraint(equalTo: trailingAnchor),
			])
		}
		
		required init?(coder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}
	}
	
	private let content: [UIView]
	var pageChanged: ((Int) -> Void)?
	
	init(content: [UIView]) {
		self.content = content
		let layout = UICollectionViewFlowLayout()
		layout.scrollDirection = .horizontal
		super.init(frame: .zero, collectionViewLayout: layout)
		
		translatesAutoresizingMaskIntoConstraints = false
			
		isPagingEnabled = true
		showsVerticalScrollIndicator = false
		showsHorizontalScrollIndicator = false
		allowsMultipleSelection = false
		delegate = self
		dataSource = self
		backgroundColor = nil
		register(PageViewCellView.self, forCellWithReuseIdentifier: "cell")
	}
	
	func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
		let item = Int(targetContentOffset.pointee.x / scrollView.frame.width)
		pageChanged?(item)
	}
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		content.count
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! PageViewCellView
		let content = self.content[indexPath.row]
		cell.fill(view: content)
		return cell
	}
	
	public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		CGSize(width: collectionView.frame.width, height: collectionView.frame.height)
    }

	public func collectionView(_ collectionView: UICollectionView,
						layout collectionViewLayout: UICollectionViewLayout,
						insetForSectionAt section: Int) -> UIEdgeInsets {
		.zero
	}
	
	public func collectionView(_ collectionView: UICollectionView,
						layout collectionViewLayout: UICollectionViewLayout,
						minimumLineSpacingForSectionAt section: Int) -> CGFloat {
		0
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class ColouredSquare: View {
	init(colour: UIColor = .black) {
		super.init()
		
		backgroundColor = colour
		layer.cornerRadius = 8
		layer.borderWidth = 0
		layer.borderColor = UIColor.black.cgColor
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class View: UIView {
	init() {
		super.init(frame: .zero)
		translatesAutoresizingMaskIntoConstraints = false
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func fill(with view: UIView, padding: UIEdgeInsets = .zero) {
		NSLayoutConstraint.activate([
			view.topAnchor.constraint(equalTo: topAnchor, constant: padding.top),
			view.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding.bottom),
			view.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding.left),
			view.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding.right),
		])
	}
}

extension UIViewController {
    func alert(title: String?, message: String?, handler: ((UIAlertAction) -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: handler))
        self.present(alert, animated: true, completion: nil)
    }

    func confirm(title: String?, message: String?, handler: ((UIAlertAction) -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: handler))
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        self.present(alert, animated: true, completion: nil)
    }
}

protocol QuestionPanelDelegate {
	func tabCount(panel: QuestionPanel) -> Int
	func configure(panel: QuestionPanel, tab: Int, cell: QuickPanelCellView)
	func configure(panel: QuestionPanel, tab: Int, label: Label)
	func configure(panel: QuestionPanel, tab: Int, content: View)
}

class QuickPanelCellView: UICollectionViewCell {
	let label = Label()
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		
		translatesAutoresizingMaskIntoConstraints = false
		
		addSubview(label)
		NSLayoutConstraint.activate([
			label.centerXAnchor.constraint(equalTo: centerXAnchor),
			label.centerYAnchor.constraint(equalTo: centerYAnchor)
		])
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class QuestionPanel: View {
	private lazy var collection: UICollectionView = { [unowned self] in
		let layout = UICollectionViewFlowLayout()
		layout.scrollDirection = .horizontal
		
		let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
		view.translatesAutoresizingMaskIntoConstraints = false
		view.showsVerticalScrollIndicator = false
		view.showsHorizontalScrollIndicator = false
		view.allowsMultipleSelection = false
		view.delegate = self
		view.dataSource = self
		view.backgroundColor = nil
		view.register(QuickPanelCellView.self, forCellWithReuseIdentifier: "cell")
		
		return view
	}()
	private let content = View()
	private let theme = CodeComplete.theme
	
	private var selection = 0
	
	var delegate: QuestionPanelDelegate?
	
	override init() {
		super.init()
		
		layer.cornerRadius = 8
		layer.masksToBounds = true
        clipsToBounds = true
		
		content.backgroundColor = theme.tertiary
		collection.backgroundColor = theme.secondary
		
		addSubview(content)
		addSubview(collection)
		
		NSLayoutConstraint.activate([
			collection.leadingAnchor.constraint(equalTo: leadingAnchor),
			collection.topAnchor.constraint(equalTo: topAnchor),
			collection.trailingAnchor.constraint(equalTo: trailingAnchor),
			collection.heightAnchor.constraint(equalToConstant: 48),
			
			content.topAnchor.constraint(equalTo: collection.bottomAnchor),
			content.bottomAnchor.constraint(equalTo: bottomAnchor),
			content.leadingAnchor.constraint(equalTo: leadingAnchor),
			content.trailingAnchor.constraint(equalTo: trailingAnchor),
		])
	}
	
	func set(index: Int) {
		content.subviews.forEach { $0.removeFromSuperview() }
		
		selection = index
		collection.selectItem(at: IndexPath(item: index, section: 0), animated: true, scrollPosition: .top)
		collection.reloadData()
		collection.scrollToItem(at: IndexPath(item: index, section: 0), at: .right, animated: true)
		
		Analytics.logEvent(AnalyticsEventSelectContent, parameters: [
			AnalyticsParameterItemID: "\(index)",
			AnalyticsParameterItemName: "\(index)",
			AnalyticsParameterContentType: "tab"
		])
		
		delegate?.configure(panel: self, tab: index, content: content)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

extension QuestionPanel: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		delegate?.tabCount(panel: self) ?? 0
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! QuickPanelCellView
		delegate?.configure(panel: self, tab: indexPath.row, cell: cell)
		
		if selection == indexPath.row {
			cell.label.textColor = theme.textPrimaryHighlighted
			cell.backgroundColor = theme.tertiary
		} else {
			cell.label.textColor = theme.textPrimary
			cell.backgroundColor = theme.secondary
		}
		
		return cell
	}
	
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		set(index: indexPath.row)
	}
	
	public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		CGSize(width: 140, height: 48)
    }

	public func collectionView(_ collectionView: UICollectionView,
						layout collectionViewLayout: UICollectionViewLayout,
						insetForSectionAt section: Int) -> UIEdgeInsets {
		.zero
	}
	
	public func collectionView(_ collectionView: UICollectionView,
						layout collectionViewLayout: UICollectionViewLayout,
						minimumLineSpacingForSectionAt section: Int) -> CGFloat {
		0
	}
}

class HtmlView: UITextView {
	init(content: String) {
		super.init(frame: .zero, textContainer: nil)
		translatesAutoresizingMaskIntoConstraints = false
		isEditable = false
		isSelectable = false
		isScrollEnabled = true
		showsHorizontalScrollIndicator = true
		showsVerticalScrollIndicator = true
		backgroundColor = nil
		
		let html = """
		<!DOCTYPE html>
		<html lang="en">
			<head>
				<meta charset="utf-8">
				<style>\(CodeComplete.theme.css)</style>
			</head>

			<body><div class="container">\(content)</div></body>
		</html>
		"""
		let data = Data(html.utf8)
		if let attributedString = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) {
			self.attributedText = attributedString
		}
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class WebView: WKWebView {
	init(question: Question, state: String?) {
		let config = WKWebViewConfiguration()
		super.init(frame: .zero, configuration: config)
		
		translatesAutoresizingMaskIntoConstraints = false
		isOpaque = false
		backgroundColor = CodeComplete.theme.tertiary
		
		let categpry = "#\(question.Summary.Category.lowercased().split(separator: " ").joined(separator: ""))"
		var difficulty = ""
		var indicator = ""
		if question.Summary.Difficulty == 1 {
			difficulty = "Easy"
			indicator = "easy"
		} else if question.Summary.Difficulty == 2 {
			difficulty = "Medium"
			indicator = "medium"
		} else if question.Summary.Difficulty == 3 {
			difficulty = "Hard"
			indicator = "hard"
		} else if question.Summary.Difficulty == 4 {
			difficulty = "Very Hard"
			indicator = "very-hard"
		} else {
			difficulty = "Extremely Hard"
			indicator = "extremely-hard"
		}
		
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
					<span class="indicator \(indicator)"></span>
					<span class="difficulty">\(difficulty)</span>
					<span class="spacer"></span>
					<span class="categpry">\(categpry)</span>
				</div>
				<div class="container">\(question.PromptHTML)</div>
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

class CodeEditor: SyntaxTextView {
	init() {
		super.init(frame: .zero)
		translatesAutoresizingMaskIntoConstraints = false
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class ActionButton: UIButton {
	var action: (() -> Void)?
	
	init(text: String = "", padding: UIEdgeInsets = UIEdgeInsets(top: 1, left: 16, bottom: 1, right: 16)) {
		super.init(frame: .zero)
		setTitle(text, for: .normal)
		backgroundColor = CodeComplete.theme.action
		setTitleColor(CodeComplete.theme.textPrimary, for: .normal)
		contentEdgeInsets = padding
		
		addTarget(self, action: #selector(runAction), for: .touchUpInside)
	}
	
	@objc func runAction() {
		action?()
	}
	
	func set(enabled: Bool) {
		backgroundColor = enabled ? CodeComplete.theme.action : CodeComplete.theme.disabled
		isEnabled = enabled
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class ActionImageButton: UIButton {
	var action: (() -> Void)?
	
	init(systemIcon: String, padding: UIEdgeInsets = UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 16)) {
		super.init(frame: .zero)
		let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold, scale: .large)
		let boldSmallSymbolImage = UIImage(systemName: systemIcon, withConfiguration: config)
		tintColor = CodeComplete.theme.textPrimary
		contentEdgeInsets = padding
		setImage(boldSmallSymbolImage, for: .normal)
		backgroundColor = CodeComplete.theme.action
		translatesAutoresizingMaskIntoConstraints = false
		addTarget(self, action: #selector(runAction), for: .touchUpInside)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func set(enabled: Bool) {
		backgroundColor = enabled ? CodeComplete.theme.action : CodeComplete.theme.disabled
		isEnabled = enabled
	}
	
	@objc func runAction() {
		action?()
	}
}

class Link: ActionButton {
	override init(text: String = "", padding: UIEdgeInsets = UIEdgeInsets(top: 1, left: 16, bottom: 1, right: 16)) {
		super.init(text: text, padding: padding)
		backgroundColor = nil
		setTitleColor(UIColor(red: 74/255, green: 144/255, blue: 226/255, alpha: 1.0), for: .normal)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class ImageButton: UIButton {
	var action: (() -> Void)?
	
	init(systemIcon: String, padding: UIEdgeInsets = UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 16)) {
		super.init(frame: .zero)
		let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold, scale: .large)
		let boldSmallSymbolImage = UIImage(systemName: systemIcon, withConfiguration: config)
		tintColor = CodeComplete.theme.textPrimary
		contentEdgeInsets = padding
		setImage(boldSmallSymbolImage, for: .normal)
		translatesAutoresizingMaskIntoConstraints = false
		
		addTarget(self, action: #selector(runAction), for: .touchUpInside)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	@objc func runAction() {
		action?()
	}
}

class IconView: UIImageView {
	init(systemIcon: String, color: UIColor, scale: UIImage.SymbolScale = .default) {
		let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold, scale: scale)
		let image = UIImage(
			systemName: systemIcon,
			withConfiguration: config
		)!.withTintColor(
			color,
			renderingMode: .alwaysOriginal
		)
		super.init(image: image)
		translatesAutoresizingMaskIntoConstraints = false
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class ActionLabel: View {
	private let label = Label()
	private var gesture: UITapGestureRecognizer!
	
	var tapUpInside: ((ActionLabel) -> Void)?

	init(text: String = "") {
		super.init()
		
		gesture = UITapGestureRecognizer(target: self, action: #selector(tapped))
		addGestureRecognizer(gesture)
		
		label.text = text
		layer.cornerRadius = 4
		addSubview(label)
		
		NSLayoutConstraint.activate([
			label.topAnchor.constraint(equalTo: topAnchor, constant: 1),
			label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
			label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
			label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8)
		])
	}
	
	@objc func tapped() {
		tapUpInside?(self)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class LabelCollectionView: UICollectionView, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
	class LabelCellView: UICollectionViewCell {
		let label = Label()
		let container = View()
		
		override init(frame: CGRect) {
			super.init(frame: frame)
			
			container.layer.cornerRadius = 4
			container.addSubview(label)
			
			addSubview(container)
			
			NSLayoutConstraint.activate([
				label.topAnchor.constraint(equalTo: container.topAnchor, constant: 1),
				label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -1),
				label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
				label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
				
				container.centerXAnchor.constraint(equalTo: centerXAnchor),
				container.centerYAnchor.constraint(equalTo: centerYAnchor)
			])
		}
		
		required init?(coder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}
	}
	
	private let items: [String]
	private var current = 0
	var selection: ((Int) -> Void)?
	
	init(items: [String], direction: UICollectionView.ScrollDirection) {
		self.items = items
		let layout = UICollectionViewFlowLayout()
		layout.scrollDirection = direction
		
		super.init(frame: .zero, collectionViewLayout: layout)
		
		translatesAutoresizingMaskIntoConstraints = false
		showsVerticalScrollIndicator = true
		showsHorizontalScrollIndicator = false
		allowsMultipleSelection = false
		delegate = self
		dataSource = self
		backgroundColor = nil
		register(LabelCellView.self, forCellWithReuseIdentifier: "cell")
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		items.count
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! LabelCellView
		cell.label.text = items[indexPath.row]
		cell.label.textColor =  CodeComplete.theme.textPrimary
		
		if indexPath.row == current {
			cell.container.backgroundColor = CodeComplete.theme.action
		} else {
			cell.container.backgroundColor = nil
		}
		
		return cell
	}
	
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		selection?(indexPath.row)
		current = indexPath.row
		collectionView.reloadData()
	}
	
	public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		CGSize(width: 100, height: 48)
    }
	
	public func collectionView(_ collectionView: UICollectionView,
						layout collectionViewLayout: UICollectionViewLayout,
						insetForSectionAt section: Int) -> UIEdgeInsets {
		.zero
	}
	
	public func collectionView(_ collectionView: UICollectionView,
						layout collectionViewLayout: UICollectionViewLayout,
						minimumLineSpacingForSectionAt section: Int) -> CGFloat {
		0
	}
}

class MultipleCodeEditors: View {
	private var editors: [CodeEditor]
	private let codeContainer = View()
	private var current: Int
	let actions = ScrollableStackView(padding: 0, spacing: 0)
	
	init(_ count: Int) {
		editors = [CodeEditor](repeating: CodeEditor(), count: count)
		current = 0
		super.init()
		
		for index in 0..<count {
			editors[index] = CodeEditor()
		}
		
		let labels = editors.enumerated().map { "Solution \($0.offset + 1)" }
		let buttonContainer = LabelCollectionView(items: labels, direction: .horizontal)
		buttonContainer.backgroundColor = CodeComplete.theme.tertiary
		buttonContainer.selection = {
			self.codeContainer.subviews.forEach { $0.removeFromSuperview() }
			self.current = $0
			let editor = self.editors[$0]
			self.codeContainer.addSubview(editor)
			self.codeContainer.fill(with: editor)
		}
		
		addSubview(buttonContainer)
		addSubview(codeContainer)
		addSubview(actions)
		
		let editor = editors[current]
		codeContainer.addSubview(editor)
		codeContainer.fill(with: editor)
		
		NSLayoutConstraint.activate([
			actions.topAnchor.constraint(equalTo: topAnchor),
			actions.leadingAnchor.constraint(equalTo: leadingAnchor),
			actions.widthAnchor.constraint(equalToConstant: 48),
			actions.bottomAnchor.constraint(equalTo: bottomAnchor),
			
			buttonContainer.topAnchor.constraint(equalTo: topAnchor),
			buttonContainer.leadingAnchor.constraint(equalTo: actions.trailingAnchor, constant: 8),
			buttonContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
			buttonContainer.heightAnchor.constraint(equalToConstant: 32),
			
			codeContainer.topAnchor.constraint(equalTo: buttonContainer.bottomAnchor),
			codeContainer.leadingAnchor.constraint(equalTo: actions.trailingAnchor),
			codeContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
			codeContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
		])
	}
	
	func getCurrent() -> Int {
		return current
	}
	
	func getCurrentText() -> String {
		return editors[current].text
	}
	
	func setCurrent(text: String) {
		self.set(text: text, at: current)
	}
	
	func set(text: String, at index: Int) {
		guard index < editors.count else { fatalError("There are only \(editors.count) editors. Cannot access \(index)") }
		editors[index].text = text
	}
	
	func set(delegate: SyntaxTextViewDelegate) {
		editors.forEach { $0.delegate = delegate }
	}
	
	func set(edittable: Bool) {
		editors.forEach { $0.contentTextView.isEditable = edittable }
	}
	
	func set(theme: SourceCodeTheme) {
		editors.forEach { $0.theme = theme }
	}
	
	func index(of: CodeEditor) -> Int? {
		editors.firstIndex(of: of)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class GroupByView: View {
	private let difficulty = ActionLabel(text: "Group by Difficulty")
	private let category = ActionLabel(text: "Group by Category")
	
	var onChange: (() -> Void)?
	var selection: Group = .difficulty {
		didSet {
			if selection == .category {
				self.category.backgroundColor = CodeComplete.theme.action
				self.difficulty.backgroundColor = nil
			} else {
				self.difficulty.backgroundColor = CodeComplete.theme.action
				self.category.backgroundColor = nil
			}
		}
	}
	
	override init() {
		super.init()
		
		difficulty.backgroundColor = CodeComplete.theme.action
		difficulty.tapUpInside = { _ in
			self.selection = .difficulty
			self.onChange?()
		}
		category.tapUpInside = { _ in
			self.selection = .category
			self.onChange?()
		}
		
		addSubview(difficulty)
		addSubview(category)
		NSLayoutConstraint.activate([
			difficulty.topAnchor.constraint(equalTo: topAnchor),
			difficulty.bottomAnchor.constraint(equalTo: bottomAnchor),
			difficulty.leadingAnchor.constraint(equalTo: leadingAnchor),
			
			category.topAnchor.constraint(equalTo: topAnchor),
			category.bottomAnchor.constraint(equalTo: bottomAnchor),
			category.leadingAnchor.constraint(equalTo: difficulty.trailingAnchor, constant: 16),
		])
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class HeaderView: View, UISearchBarDelegate {
	private lazy var search: UISearchBar = { [unowned self] in
		let view = UISearchBar()
		view.translatesAutoresizingMaskIntoConstraints = false
		view.delegate = self
		
		return view
	}()
	
	private let group = GroupByView()
//	private let filter = ActionLabel(text: "Filter")
	
	var onChange: (() -> Void)?
	
	override init() {
		super.init()
		
		group.onChange = {
			self.onChange?()
		}
		
		search.placeholder = "Search"
		search.barTintColor = CodeComplete.theme.primary
		search.searchBarStyle = .minimal

		let textFieldInsideSearchBar = search.value(forKey: "searchField") as? UITextField
		textFieldInsideSearchBar?.textColor = CodeComplete.theme.textPrimary
		let glassIconView = textFieldInsideSearchBar?.leftView as? UIImageView
		glassIconView?.image = glassIconView?.image?.withRenderingMode(.alwaysTemplate)
		glassIconView?.tintColor = CodeComplete.theme.textPrimary
		let textFieldInsideSearchBarLabel = textFieldInsideSearchBar!.value(forKey: "placeholderLabel") as? UILabel
		textFieldInsideSearchBarLabel?.textColor = CodeComplete.theme.textPrimary
		
		addSubview(search)
		addSubview(group)
//		addSubview(filter)
		
		NSLayoutConstraint.activate([
			search.topAnchor.constraint(equalTo: topAnchor),
			search.leadingAnchor.constraint(equalTo: leadingAnchor),
			search.trailingAnchor.constraint(equalTo: trailingAnchor),
			
			group.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 16),
			group.bottomAnchor.constraint(equalTo: bottomAnchor),
			group.leadingAnchor.constraint(equalTo: leadingAnchor),
			group.widthAnchor.constraint(equalToConstant: 336),
			
//			filter.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 16),
//			filter.bottomAnchor.constraint(equalTo: bottomAnchor),
//			filter.trailingAnchor.constraint(equalTo: trailingAnchor),
//			filter.widthAnchor.constraint(equalToConstant: 56),
		])
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func filter(questions: [Questions]) -> QuestionsViewModel {
		let filtered: [Questions]
		if let text = search.searchTextField.text, text.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
			filtered = questions.filter({ $0.Name.lowercased().contains(text.lowercased()) })
		} else {
			filtered = questions
		}
		
		var dictionary: [String: [Questions]]
		let sections: [String]
		
		dictionary = Dictionary(grouping: filtered) { group.selection == .difficulty ? "\($0.Difficulty)" : $0.Category }
		sections = Array(dictionary.keys.sorted())
		sections.forEach { dictionary[$0]!.sort{ $0.Metadata.number > $1.Metadata.number } }
		
		return QuestionsViewModel(questions: dictionary, sections: sections, grouping: group.selection)
	}
	
	func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
		self.onChange?()
	}
}

class BlurredView: View {
	private let blurView: UIVisualEffectView = {
		let blur = UIBlurEffect(style: .light)
		let view = UIVisualEffectView(effect: blur)
		view.translatesAutoresizingMaskIntoConstraints = false
		view.isUserInteractionEnabled = true
		
		return view
	}()
	
	private let message: Label = {
		let view = Label()
		view.isUserInteractionEnabled = true
		view.textAlignment = .center
		
		return view
	}()
	private var gesture: UITapGestureRecognizer!
	var revealed: (() -> Void)?
	
	init(content: UIView, tip: String = "Tap to reveal") {
		super.init()
		
		gesture = UITapGestureRecognizer(target: self, action: #selector(showContent))
		message.text = tip
		
		addSubview(content)
		addSubview(blurView)
		addSubview(message)
		
		blurView.addGestureRecognizer(gesture)
		self.message.addGestureRecognizer(gesture)
		
		fill(with: content)
		fill(with: blurView)
		fill(with: self.message)
	}
	
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	@objc func showContent() {
		blurView.removeGestureRecognizer(gesture)
		message.removeGestureRecognizer(gesture)
		
		blurView.removeFromSuperview()
		message.removeFromSuperview()
		revealed?()
	}
}

class SubscriptionButton: View {
	var action: (() -> Void)?
	private var gesture: UITapGestureRecognizer!
	
	init(package: Purchases.Package, formatter: NumberFormatter) {
		super.init()
		
		gesture = UITapGestureRecognizer(target: self, action: #selector(tapped))
		addGestureRecognizer(gesture)
		
		isUserInteractionEnabled = true
		backgroundColor = CodeComplete.theme.action
		layer.cornerRadius = 8
		layer.borderWidth = 2
		layer.borderColor = UIColor.white.cgColor
		
		let title = Label(text: package.product.localizedTitle)
		title.isUserInteractionEnabled = false
		title.font = .boldSystemFont(ofSize: 18)
		let subtitle = Label(text: package.product.localizedDescription)
		subtitle.numberOfLines = 0
		subtitle.textColor = .lightGray
		subtitle.font = .systemFont(ofSize: 14)
		subtitle.isUserInteractionEnabled = false
		
		let duration = Label(text: package.span())
		duration.textAlignment = .right
		duration.isUserInteractionEnabled = false
		let price = Label(text: package.localizedPriceString)
		price.textAlignment = .right
		price.isUserInteractionEnabled = false
		let unit = Label(text: package.unitPrice(priceFormatter: formatter))
		unit.isUserInteractionEnabled = false
		unit.textAlignment = .right
		unit.textColor = .lightGray
		unit.font = .systemFont(ofSize: 14)
		
		let left = View()
		left.addSubview(title)
		left.addSubview(subtitle)
		left.isUserInteractionEnabled = false
		
		let right = View()
		right.addSubview(duration)
		right.addSubview(price)
		right.addSubview(unit)
		right.isUserInteractionEnabled = false
		
		addSubview(left)
		addSubview(right)
		
		NSLayoutConstraint.activate([
			left.topAnchor.constraint(equalTo: topAnchor, constant: 16),
			left.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
			left.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
			left.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.5),
			
			right.topAnchor.constraint(equalTo: topAnchor, constant: 16),
			right.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
			right.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
			right.leadingAnchor.constraint(equalTo: left.trailingAnchor),
			
			title.topAnchor.constraint(equalTo: left.topAnchor),
			title.leadingAnchor.constraint(equalTo: left.leadingAnchor),
			title.trailingAnchor.constraint(equalTo: left.trailingAnchor),
			subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
			subtitle.leadingAnchor.constraint(equalTo: left.leadingAnchor),
			subtitle.trailingAnchor.constraint(equalTo: left.trailingAnchor),
			subtitle.bottomAnchor.constraint(equalTo: left.bottomAnchor),
			
			duration.topAnchor.constraint(equalTo: right.topAnchor),
			duration.leadingAnchor.constraint(equalTo: right.leadingAnchor),
			duration.trailingAnchor.constraint(equalTo: right.trailingAnchor),
			price.topAnchor.constraint(equalTo: duration.bottomAnchor),
			price.leadingAnchor.constraint(equalTo: right.leadingAnchor),
			price.trailingAnchor.constraint(equalTo: right.trailingAnchor),
			unit.topAnchor.constraint(equalTo: price.bottomAnchor),
			unit.leadingAnchor.constraint(equalTo: right.leadingAnchor),
			unit.trailingAnchor.constraint(equalTo: right.trailingAnchor),
			unit.bottomAnchor.constraint(equalTo: right.bottomAnchor),
		])
	}
	
	@objc func tapped() {
		action?()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class PurchaseView: View, UITextViewDelegate {
	private let content = ScrollableStackView()
	private let priceFormatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.numberStyle = .currency
		
		return formatter
	}()
	private let legal: UITextView = {
		let view = UITextView()
		view.translatesAutoresizingMaskIntoConstraints = false
		view.isSelectable = true
		view.textAlignment = .center
		view.font = .systemFont(ofSize: 13)
		view.textColor = CodeComplete.theme.textPrimary
		view.isEditable = false
		view.isScrollEnabled = false
		view.showsHorizontalScrollIndicator = false
		view.showsVerticalScrollIndicator = false
		view.dataDetectorTypes = .link
		view.tintColor = CodeComplete.theme.textPrimary
		view.backgroundColor = nil
		
		return view
	}()
	
	var purchase: ((Purchases.Package) -> Void)?
	var restore: (() -> Void)?
	
	init(offer: Purchases.Offering) {
		super.init()
		
		layer.cornerRadius = 8
		backgroundColor = UIColor.black.withAlphaComponent(0.5)
		
		let purchaseTitle = Label(text: "Upgrade for Total Access")
		purchaseTitle.font = UIFont.boldSystemFont(ofSize: 24)
		purchaseTitle.textAlignment = .center
		content.contentView.addArrangedSubview(purchaseTitle)
		
		let description = Label(text: "Subscribe for full access to all questions which provides you with the ultimate resource to prepare for coding interviews. It's everything you need, in one streamlined app.")
		description.numberOfLines = 0
		description.textAlignment = .center
		content.contentView.addArrangedSubview(description)
		
		offer.availablePackages.forEach { package in
			priceFormatter.locale = package.product.priceLocale
			let button = SubscriptionButton(package: package, formatter: priceFormatter)
			button.action = {
				self.purchase?(package)
			}
			content.contentView.addArrangedSubview(button)
		}
		
		let restore = Link(text: "Restore Purchases")
		restore.action = {
			self.restore?()
		}
		content.contentView.addArrangedSubview(restore)
		
		let paragraphStyle: NSMutableParagraphStyle = NSMutableParagraphStyle()
		paragraphStyle.alignment = NSTextAlignment.center
		let attributedString = NSMutableAttributedString(string: "Terms of Service and Privacy Policy", attributes:  [NSAttributedString.Key.paragraphStyle : paragraphStyle])
		
		attributedString.addAttribute(
			.link,
			value: "https://vijaysharma.ca/code-complete-tos/",
			range: NSRange(location: 0, length: 16)
		)
		attributedString.addAttribute(
			.link,
			value: "https://vijaysharma.ca/code-complete-privacy/",
			range: NSRange(location: 21, length: 14)
		)

		legal.delegate = self
		legal.attributedText = attributedString
		content.contentView.addArrangedSubview(legal)
		
		addSubview(content)
		fill(with: content, padding: UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0))
	}
	
	func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        UIApplication.shared.open(URL)
        return false
    }
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class LockedView: View {
	private let blurView: UIVisualEffectView = {
		let blur = UIBlurEffect(style: .light)
		let view = UIVisualEffectView(effect: blur)
		view.translatesAutoresizingMaskIntoConstraints = false
		view.isUserInteractionEnabled = true
		
		return view
	}()
	private var current: UIView?
	
	override init() {
		super.init()
		
		addSubview(blurView)
		fill(with: blurView)
	}
	
	func set(dialog: UIView, size: CGSize) {
		if let current = current {
			current.removeFromSuperview()
		}
		
		current = dialog
		addSubview(dialog)
		NSLayoutConstraint.activate([
			dialog.centerYAnchor.constraint(equalTo: centerYAnchor),
			dialog.centerXAnchor.constraint(equalTo: centerXAnchor),
			dialog.widthAnchor.constraint(equalToConstant: size.width),
			dialog.heightAnchor.constraint(equalToConstant: size.height),
		])
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class TestView: View {
	var revealed: (() -> Void)?
	init(
		title: String,
		test: NSAttributedString?
	) {
		super.init()
		
		layer.cornerRadius = 8
		clipsToBounds = true
		backgroundColor = CodeComplete.theme.secondary
		
		let titleLabel = Label(text: String(title))
		let titleView = View()
		titleView.addSubview(titleLabel)

		let testContainer = TitleWithContentView(title: "Input(s)", text: test)
		let wrappedView = BlurredView(content: testContainer, tip: "Tap to view test")
		wrappedView.revealed = {
			self.revealed?()
		}
		
		addSubview(titleView)
		addSubview(wrappedView)
		
		NSLayoutConstraint.activate([
			titleLabel.topAnchor.constraint(equalTo: titleView.topAnchor),
			titleLabel.bottomAnchor.constraint(equalTo: titleView.bottomAnchor),
			titleLabel.leadingAnchor.constraint(equalTo: titleView.leadingAnchor, constant: 16),
			titleLabel.trailingAnchor.constraint(equalTo: titleView.trailingAnchor),
			
			titleView.topAnchor.constraint(equalTo: topAnchor),
			titleView.trailingAnchor.constraint(equalTo: trailingAnchor),
			titleView.leadingAnchor.constraint(equalTo: leadingAnchor),
			titleView.heightAnchor.constraint(equalToConstant: 48),
			
			wrappedView.topAnchor.constraint(equalTo: titleView.bottomAnchor),
			wrappedView.trailingAnchor.constraint(equalTo: trailingAnchor),
			wrappedView.leadingAnchor.constraint(equalTo: leadingAnchor),
			wrappedView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
		])
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class TestsView: ScrollableStackView {
	var revealed: ((Int) -> Void)?
	init(question: Question, json: JSONPrettyPrinter, highlightr: Highlightr?) {
		super.init()
		
		let tests = question.JSONTests
		for (index, test) in tests.enumerated() {
			let format = json.stringify(json: test)
			let text = highlightr?.highlight(format, as: "json")
			let view = TestView(title: "Test Case \(index + 1)", test: text)
			view.revealed = {
				self.revealed?(index)
			}
			super.contentView.addArrangedSubview(view)
		}
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class TitleWithContentView: UIStackView {
	init(title: String, text: NSAttributedString?) {
		super.init(frame: .zero)
		translatesAutoresizingMaskIntoConstraints = false
		axis = .vertical
		distribution = .fill
		alignment = .fill
		spacing = 8
		
		let inputTitle = Label(text: title)
		inputTitle.font = UIFont.boldSystemFont(ofSize: 17)
		let titleContainer = View()
		titleContainer.addSubview(inputTitle)
		titleContainer.fill(with: inputTitle, padding: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16))
		
		let inputText = Label()
		inputText.numberOfLines = 0
		inputText.attributedText = text
//		let testLabel = TextField()
//		testLabel.attributedText = test
//		testLabel.isSelectable = true
//		testLabel.isEditable = false
//		testLabel.isScrollEnabled = true
//		testLabel.showsHorizontalScrollIndicator = true
//		testLabel.showsVerticalScrollIndicator = false
//		testLabel.backgroundColor = nil
		let contentContainer = View()
		contentContainer.addSubview(inputText)
		contentContainer.fill(with: inputText, padding: UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 16))
		contentContainer.backgroundColor = CodeComplete.theme.primary
		
		addArrangedSubview(titleContainer)
		addArrangedSubview(contentContainer)
	}
	
	required init(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class ResultView: View {
	private let contentView: UIStackView = {
		let view = UIStackView()
		view.translatesAutoresizingMaskIntoConstraints = false
		view.axis = .vertical
		view.distribution = .fill
		view.alignment = .fill
		view.spacing = 16
		
		return view
	}()
	
	var revealed: (() -> Void)?
	
	init(
		success: Bool,
		title: String,
		ours: NSAttributedString?,
		yours: NSAttributedString?,
		input: NSAttributedString?,
		hide: Bool
	) {
		super.init()
		
		layer.cornerRadius = 8
		clipsToBounds = true
		backgroundColor = CodeComplete.theme.secondary
		
		let titleLabel = Label(text: String(title))
		let titleIcon = IconView(
			systemIcon: success ? "checkmark.circle.fill": "xmark.circle.fill",
			color: success ? CodeComplete.theme.successColour : CodeComplete.theme.failedColour
		)
		let titleView = View()
		titleView.addSubview(titleIcon)
		titleView.addSubview(titleLabel)
		
		if let ours = ours {
			contentView.addArrangedSubview(TitleWithContentView(title: "Our Code's Output", text: ours))
		}
		
		if let yours = yours {
			contentView.addArrangedSubview(TitleWithContentView(title: "Your Code's Output", text: yours))
		}
		
		contentView.addArrangedSubview(TitleWithContentView(title: "Input(s)", text: input))
		
		let wrappedView: UIView
		if hide {
			let blurred = BlurredView(content: contentView, tip: "Tap to view test")
			blurred.revealed = {
				self.revealed?()
			}
			wrappedView = blurred
		} else {
			wrappedView = contentView
		}
		
		addSubview(titleView)
		addSubview(wrappedView)
		
		NSLayoutConstraint.activate([
			titleIcon.centerYAnchor.constraint(equalTo: titleView.centerYAnchor),
			titleIcon.leadingAnchor.constraint(equalTo: titleView.leadingAnchor, constant: 16),
			titleIcon.widthAnchor.constraint(equalToConstant: 24),
			titleIcon.heightAnchor.constraint(equalToConstant: 24),
			
			titleLabel.topAnchor.constraint(equalTo: titleView.topAnchor),
			titleLabel.bottomAnchor.constraint(equalTo: titleView.bottomAnchor),
			titleLabel.leadingAnchor.constraint(equalTo: titleIcon.trailingAnchor, constant: 16),
			titleLabel.trailingAnchor.constraint(equalTo: titleView.trailingAnchor),
			
			titleView.topAnchor.constraint(equalTo: topAnchor),
			titleView.trailingAnchor.constraint(equalTo: trailingAnchor),
			titleView.leadingAnchor.constraint(equalTo: leadingAnchor),
			titleView.heightAnchor.constraint(equalToConstant: 48),
			
			wrappedView.topAnchor.constraint(equalTo: titleView.bottomAnchor),
			wrappedView.trailingAnchor.constraint(equalTo: trailingAnchor),
			wrappedView.leadingAnchor.constraint(equalTo: leadingAnchor),
			wrappedView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
		])
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class ResultViewHeader: View {
	private let title: Label
	private let subtitle: Label
	
	init(title: String, subtitle: String) {
		self.title = Label(text: title)
		self.subtitle = Label(text: subtitle)
		
		super.init()
		
		self.title.textAlignment = .center
		self.title.font = CodeComplete.theme.questionTitle
		self.title.numberOfLines = 0
		self.subtitle.textAlignment = .center
		self.subtitle.textColor = .lightGray
		
		addSubview(self.title)
		addSubview(self.subtitle)
		
		NSLayoutConstraint.activate([
			self.title.topAnchor.constraint(equalTo: topAnchor),
			self.title.leadingAnchor.constraint(equalTo: leadingAnchor),
			self.title.trailingAnchor.constraint(equalTo: trailingAnchor),
			self.title.bottomAnchor.constraint(equalTo: self.subtitle.topAnchor, constant: -8),
			
			self.subtitle.leadingAnchor.constraint(equalTo: leadingAnchor),
			self.subtitle.trailingAnchor.constraint(equalTo: trailingAnchor),
			self.subtitle.bottomAnchor.constraint(equalTo: bottomAnchor),
		])
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class ResultsView: ScrollableStackView {
	var revealed: ((Int) -> Void)?
	init(
		question: Question,
		results: [TestResult],
		hidden: [Bool],
		json: JSONPrettyPrinter,
		highlightr: Highlightr?,
		success: Bool,
		showActual: Bool
	) {
		super.init()

		let tests = question.JSONTests
		let answers = question.JSONAnswers
		
		let count = tests.count
		var successCount = 0
		var views: [ResultView] = []
		
		for (index, test) in tests.enumerated() {
			let result = results[index]
			let actual = result.actual as? String ?? (result.success ? answers[index] : "undefined")
			let expected = result.expected as? String ?? answers[index]
			successCount = successCount + (result.success ? 1 : 0)
			let view = ResultView(
				success: result.success,
				title: "Test Case \(index + 1)",
				ours: highlightr?.highlight(json.stringify(json: expected), as: "json"),
				yours: showActual ? highlightr?.highlight(json.stringify(json: actual), as: "json") : nil,
				input: highlightr?.highlight(json.stringify(json: test), as: "json"),
				hide: hidden[index]
			)
			view.revealed = {
				self.revealed?(index)
			}
			views.append(view)
		}
		
		super.contentView.addArrangedSubview(ResultViewHeader(
			title: success ? "Yay, code passed all the test cases!" : "Aww, code failed at least one of the test cases.",
			subtitle: "\(successCount)/\(count) test cases passed"
		))
		views.forEach { super.contentView.addArrangedSubview($0) }
		
		layer.borderWidth = 2
		layer.borderColor = success ? CodeComplete.theme.successColour.cgColor : CodeComplete.theme.failedColour.cgColor
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class ScrollableStackView: UIScrollView {
	let contentView: UIStackView = {
		let view = UIStackView()
		view.translatesAutoresizingMaskIntoConstraints = false
		view.axis = .vertical
		view.distribution = .fill
		view.alignment = .fill
		
		return view
	}()
	
	init(padding: CGFloat = 16, spacing: CGFloat = 16) {
		super.init(frame: .zero)
		translatesAutoresizingMaskIntoConstraints = false
		
		contentView.spacing = spacing
		addSubview(contentView)
		
		let contentLayoutGuide = self.contentLayoutGuide
		let frameLayoutGuide = self.frameLayoutGuide
		NSLayoutConstraint.activate([
			contentView.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor, constant: padding),
			contentView.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor, constant: -padding),
			contentView.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor, constant: padding),
			contentView.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor),
			contentView.widthAnchor.constraint(equalTo: frameLayoutGuide.widthAnchor, constant: -2 * padding)
		])
	}
	
	func removeAllArrangedSubviews() {
		let removedSubviews = contentView.arrangedSubviews.reduce([]) { (allSubviews, subview) -> [UIView] in
			contentView.removeArrangedSubview(subview)
			return allSubviews + [subview]
		}
		
		// Deactivate all constraints
        // NSLayoutConstraint.deactivate(removedSubviews.flatMap({ $0.constraints }))
		
		// Remove the views from self
		removedSubviews.forEach({ $0.removeFromSuperview() })
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class HintsView: UIScrollView {
	class HintView: View {
		init(title: String, hint: String) {
			super.init()
			
			layer.cornerRadius = 8
			clipsToBounds = true
			
			let titleLabel = Label(text: String(title))
			let titleView = View()
			titleView.addSubview(titleLabel)
			titleView.backgroundColor = CodeComplete.theme.secondary
			
			let hintLabel = Label(text: String(hint))
			hintLabel.numberOfLines = 0
			let hintContainer = View()
			hintContainer.backgroundColor = CodeComplete.theme.secondary
			hintContainer.addSubview(hintLabel)
			hintContainer.fill(with: hintLabel, padding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
			let hintView = BlurredView(content: hintContainer, tip: "Tap to reveal \(title.lowercased())")
			
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
	
	private let contentView: UIStackView = {
		let view = UIStackView()
		view.translatesAutoresizingMaskIntoConstraints = false
		view.axis = .vertical
		view.distribution = .fill
		view.alignment = .fill
		view.spacing = 16
		
		return view
	}()
	
	init(question: Question) {
		super.init(frame: .zero)
		translatesAutoresizingMaskIntoConstraints = false
		
		let hints = question.Hints.split(separator: "\n")
		for (index, hint) in hints.enumerated() {
			contentView.addArrangedSubview(
				HintView(title: "Hint #\(index + 1)", hint: String(hint))
			)
		}
		
		contentView.addArrangedSubview(
			HintView(title: "Complexity", hint: question.SpaceTime)
		)
		
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

class PanelDelegate: QuestionPanelDelegate {
	private let panels: [QuestionPanelDelegate]
	
	init(panels: [QuestionPanelDelegate]) {
		self.panels = panels
	}
	
	func tabCount(panel: QuestionPanel) -> Int {
		panels.count
	}
	
	func configure(panel: QuestionPanel, tab: Int, label: Label) {
		panels[tab].configure(panel: panel, tab: tab, label: label)
	}
	
	func configure(panel: QuestionPanel, tab: Int, content: View) {
		panels[tab].configure(panel: panel, tab: tab, content: content)
	}
	
	func configure(panel: QuestionPanel, tab: Int, cell: QuickPanelCellView) {
		panels[tab].configure(panel: panel, tab: tab, cell: cell)
	}
}

class GenericPanel: QuestionPanelDelegate {
	private let cellName: String
	private let tabName: String
	private let content: UIView?
	private let padding: UIEdgeInsets?
	
	init(
		cellName: String,
		tabName: String,
		content: UIView? = .none,
		padding: UIEdgeInsets? = .zero
	) {
		self.cellName = cellName
		self.tabName = tabName
		self.content = content
		self.padding = padding
	}
	
	func tabCount(panel: QuestionPanel) -> Int { fatalError() }
	func configure(panel: QuestionPanel, tab: Int, cell: QuickPanelCellView) { cell.label.text = cellName }
	func configure(panel: QuestionPanel, tab: Int, label: Label) { label.text = tabName }
	func configure(panel: QuestionPanel, tab: Int, content: View) {
		if let body = self.content {
			content.addSubview(body)
			content.fill(with: body, padding: padding ?? UIEdgeInsets.zero)
		}
	}
}

class ConsoleView: View {	
	init(message: String) {
		super.init()
		
		let label = Label(text: message)
		label.textAlignment = .center
		
		addSubview(label)
		fill(with: label)
	}
	
	func set(text: String, success: Bool) {
		subviews.forEach { $0.removeFromSuperview() }
		
		layer.borderWidth = 2
		layer.borderColor = success ? CodeComplete.theme.successColour.cgColor : CodeComplete.theme.failedColour.cgColor
		
		let label = Label(text: text)
		label.numberOfLines = 0
		label.textColor = success ? CodeComplete.theme.successColour : CodeComplete.theme.failedColour
		
		let scroll = ScrollView(content: label, padding: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
		addSubview(scroll)
		fill(with: scroll)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class PromptView: View {
	private let promptView: WebView
	
	init(question: Question, state: String?) {
		promptView = WebView(question: question, state: state)
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

protocol QuestionView {
	func showPanel(panel: QuestionPanelDelegate)
}

class SplitPanel: View, QuestionView {
	private let left = QuestionPanel()
	private let right = QuestionPanel()
	
	init(leftPanels: [QuestionPanelDelegate], rightPanels: [QuestionPanelDelegate]) {
		super.init()
		right.delegate = PanelDelegate(panels: rightPanels)
		left.delegate = PanelDelegate(panels: leftPanels)
		
		addSubview(right)
		addSubview(left)
		
		NSLayoutConstraint.activate([
			left.topAnchor.constraint(equalTo: topAnchor),
			left.bottomAnchor.constraint(equalTo: bottomAnchor),
			left.leadingAnchor.constraint(equalTo: leadingAnchor),
			left.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.5, constant: -4),
			
			right.topAnchor.constraint(equalTo: topAnchor),
			right.bottomAnchor.constraint(equalTo: bottomAnchor),
			right.trailingAnchor.constraint(equalTo: trailingAnchor),
			right.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.5, constant: -4),
		])
		
		left.set(index: 0)
		right.set(index: 0)
	}
	
	func showPanel(panel: QuestionPanelDelegate) {
		if let _ = panel as? TestsPanel {
			self.left.set(index: 2)
		} else {
			self.right.set(index: 2)
		}
	}
	
	deinit {
		left.delegate = nil
		right.delegate = nil
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class SinglePanel: View, QuestionView {
	private let panel = QuestionPanel()
	
	init(panels: [QuestionPanelDelegate]) {
		super.init()
		
		panel.delegate = PanelDelegate(panels: panels)
		
		addSubview(panel)
		fill(with: panel)
		
		panel.set(index: 0)
	}
	
	deinit {
		panel.delegate = nil
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func showPanel(panel: QuestionPanelDelegate) {
		if let _ = panel as? TestsPanel {
			self.panel.set(index: 3)
		} else {
			self.panel.set(index: 5)
		}
	}
}

extension Purchases.Package {
	func unitPrice(priceFormatter: NumberFormatter) -> String {
		switch packageType {
        case .lifetime:
			return "One time"
        case .annual:
            return "\(priceFormatter.string(from: product.price.dividing(by: 12.0)) ?? "") / mo"
        case .sixMonth:
            return "\(priceFormatter.string(from: product.price.dividing(by: 6.0)) ?? "") / mo"
        case .threeMonth:
            return "\(priceFormatter.string(from: product.price.dividing(by: 3.0)) ?? "") / mo"
        case .twoMonth:
            return "\(priceFormatter.string(from: product.price.dividing(by: 2.0)) ?? "") / mo"
        case .monthly:
            return "\(localizedPriceString) / mo"
        case .weekly:
            return "\(localizedPriceString) / wk"
		default:
            return ""
        }
	}
	
	func span() -> String {
		switch packageType {
        case .lifetime:
			return "Lifetime"
        case .annual:
            return "1 Year"
        case .sixMonth:
            return "6 Months"
        case .threeMonth:
            return "3 Months"
        case .twoMonth:
            return "2 Months"
        case .monthly:
            return "1 Months"
        case .weekly:
            return "1 Week"
		default:
            return "\(identifier)"
        }
	}
}

class QuestionTimer: Label {
	private var timer: Timer? = nil
	private var date: Date? = nil
	
	init() {
		super.init(text: "00:00")
		
		backgroundColor = UIColor.black.withAlphaComponent(0.7)
		font = UIFont.systemFont(ofSize: 12)
		textAlignment = .center
		
		clipsToBounds = true;
		layer.masksToBounds = true;
		layer.cornerRadius = 10;
	}
	
	func isActive() -> Bool {
		return timer != nil
	}
	
	func start() {
		timer?.invalidate()
		date = Date()
		
		timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(fireTimer), userInfo: nil, repeats: true)
	}
	
	func stop() {
		timer?.invalidate()
		timer = nil
		date = nil
	}
	
	@objc func fireTimer() {
		guard let date = date else { return }
		let now = Date()
		let total = now.timeIntervalSince(date)
		text = duration(miliseconds: total)
	}
	
	private func duration(miliseconds: Double) -> String {
		let seconds = Int(floor(miliseconds))
		let ss = seconds % 60
		let mm = Int(floor(Double(seconds / 60))) % 60
		let hh = Int(floor(Double(seconds) / 60.0))
		if hh >= 1 {
			let s = String(format: "%02d", ss)
			let m = String(format: "%02d", mm)
			return "\(hh):\(m):\(s)"
		} else {
			let s = String(format: "%02d", ss)
			let m = String(format: "%02d", mm)
			return "\(m):\(s)"
		}
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class HorizontalProgressBar: View {
	var colour: UIColor? = .gray
	var progress: CGFloat = 0.5 {
		didSet { setNeedsDisplay() }
	}
	
	private let progressLayer = CALayer()
	private let backgroundMask = CAShapeLayer()
	
	override init() {
		super.init()
		layer.addSublayer(progressLayer)
		backgroundColor = .green
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func draw(_ rect: CGRect) {
		backgroundMask.path = UIBezierPath(roundedRect: rect, cornerRadius: rect.height * 0.25).cgPath
		layer.mask = backgroundMask
		
		let progressRect = CGRect(origin: .zero, size: CGSize(width: rect.width * progress, height: rect.height))
		
		progressLayer.frame = progressRect
		progressLayer.backgroundColor = colour?.cgColor
	}
}

class PlainCircularProgressBar: View {
	var ringWidth: CGFloat = 5
    var colour: UIColor? = .gray {
        didSet { setNeedsDisplay() }
    }
    var progress: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }

    private var progressLayer = CAShapeLayer()
    private var backgroundMask = CAShapeLayer()

    override init() {
        super.init()
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    private func setupLayers() {
        backgroundMask.lineWidth = ringWidth
        backgroundMask.fillColor = nil
        backgroundMask.strokeColor = UIColor.black.cgColor
        layer.mask = backgroundMask

        progressLayer.lineWidth = ringWidth
        progressLayer.fillColor = nil
        layer.addSublayer(progressLayer)
        layer.transform = CATransform3DMakeRotation(CGFloat(90 * Double.pi / 180), 0, 0, -1)
    }

    override func draw(_ rect: CGRect) {
        let circlePath = UIBezierPath(ovalIn: rect.insetBy(dx: ringWidth / 2, dy: ringWidth / 2))
        backgroundMask.path = circlePath.cgPath

        progressLayer.path = circlePath.cgPath
        progressLayer.lineCap = .round
        progressLayer.strokeStart = 0
        progressLayer.strokeEnd = progress
        progressLayer.strokeColor = colour?.cgColor
    }
}

class ProgressView: View {
	private let label = Label()
	private let progress = PlainCircularProgressBar()
	
	override init() {
		super.init()
		
		addSubview(progress)
		addSubview(label)
		
		label.text = "18 Questions out of 100 Completed"
		
		NSLayoutConstraint.activate([
			label.leadingAnchor.constraint(equalTo: leadingAnchor),
			label.trailingAnchor.constraint(equalTo: trailingAnchor),
			label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
			label.bottomAnchor.constraint(equalTo: progress.topAnchor, constant: -8),
			
			progress.leadingAnchor.constraint(equalTo: leadingAnchor),
			progress.trailingAnchor.constraint(equalTo: trailingAnchor),
			progress.bottomAnchor.constraint(equalTo: bottomAnchor),
			progress.heightAnchor.constraint(equalToConstant: 20)
		])
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		self.setNeedsDisplay()
		progress.setNeedsDisplay()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
