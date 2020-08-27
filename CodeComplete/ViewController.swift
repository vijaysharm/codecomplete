//
//  ViewController.swift
//  CodeComplete
//
//  Copyright © 2020 Vijay Sharma. All rights reserved.
//

import UIKit
import Firebase

class ViewController: UIViewController {
	private let filter = HeaderView()
	private lazy var collection: UICollectionView = { [unowned self] in
		let layout = UICollectionViewFlowLayout()
		layout.sectionHeadersPinToVisibleBounds = true
		
		let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
		view.translatesAutoresizingMaskIntoConstraints = false
		view.showsVerticalScrollIndicator = true
		view.showsHorizontalScrollIndicator = false
		view.allowsMultipleSelection = false
		view.delegate = self
		view.dataSource = self
		view.backgroundColor = nil
		view.register(QuestionViewCell.self, forCellWithReuseIdentifier: "cell")
		view.register(
			QuestionViewHeaderCell.self,
			forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
			withReuseIdentifier: "header"
		)
		
		return view
	}()
	
	private let questions: [Questions]
	private let service: Service
	private let database: Database
	private var filtered: QuestionsViewModel!

	init(
		questions: [Questions],
		service: Service,
		database: Database
	) {
		self.questions = questions
		self.service = service
		self.database = database
		super.init(nibName: nil, bundle: nil)
		
		title = "Code Complete"
		
		view.backgroundColor = CodeComplete.theme.primary
		view.addSubview(collection)
		view.addSubview(filter)
		
		let settingsButton = UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(settings))
		settingsButton.tintColor = CodeComplete.theme.textPrimary
		navigationItem.rightBarButtonItem = settingsButton
		
		NSLayoutConstraint.activate([
			filter.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
			filter.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
			filter.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
			
			collection.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			collection.bottomAnchor.constraint(equalTo: filter.topAnchor),
			collection.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
			collection.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
		])
		
		filter.onChange = {
			Analytics.logEvent("search", parameters: nil)

			self.filtered = self.filter.filter(questions: self.questions)
			self.collection.reloadData()
		}
		
		filtered = filter.filter(questions: self.questions)
		
		NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
	}
	
	@objc func settings() {
		let controller = SettingsViewController(service: service, database: database)
		controller.delegate = {
			self.collection.reloadData()
		}
		self.navigationController?.pushViewController(controller, animated: true)
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
	
	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		guard let flowLayout = collection.collectionViewLayout as? UICollectionViewFlowLayout else {
			return
		}
		flowLayout.invalidateLayout()
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

extension ViewController: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
	func numberOfSections(in collectionView: UICollectionView) -> Int {
		filtered.sectionCount
	}
	
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		filtered.itemCount(section)
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! QuestionViewCell
		
		let question = filtered.get(section: indexPath.section, index: indexPath.row)
		let state = database.state(name: question.Name)
		cell.set(question: question, state: state)
		service.isLocked(name: question.Name) { isLocked in
			cell.is(locked: isLocked)
		}
		
		return cell
	}
	
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		collectionView.deselectItem(at: indexPath, animated: true)
		let controller = QuestionViewController(
			provider: QuestionProvider(
				model: self.filtered,
				section: indexPath.section,
				index: indexPath.row
			),
			service: service,
			database: self.database
		)
		controller.delegate = { changes in
			collectionView.reloadData()
		}
		self.navigationController?.pushViewController(controller, animated: true)
	}
	
	public func collectionView(
		_ collectionView: UICollectionView,
		layout collectionViewLayout: UICollectionViewLayout,
		sizeForItemAt indexPath: IndexPath
	) -> CGSize {
		let fullWidthF = collectionView.frame.width - 16 - 16
		let fullWidth = Int(fullWidthF)
		let possibleColumns = fullWidth / 250
		if possibleColumns == 0 || possibleColumns == 1 {
			return CGSize(width: fullWidth, height: 190)
		}
		let size = (fullWidthF - (CGFloat(possibleColumns - 1) * 16)) / CGFloat(possibleColumns)
		return CGSize(width: size, height: 190)
    }
	
	public func collectionView(_ collectionView: UICollectionView,
						layout collectionViewLayout: UICollectionViewLayout,
						insetForSectionAt section: Int) -> UIEdgeInsets {
		.init(top: 16, left: 16, bottom: 16, right: 16)
	}
	
	public func collectionView(_ collectioknView: UICollectionView,
						layout collectionViewLayout: UICollectionViewLayout,
						minimumLineSpacingForSectionAt section: Int) -> CGFloat {
		16
	}
		
	func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
		let cell = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath) as! QuestionViewHeaderCell
		let section = filtered.get(section: indexPath.section)
		let count = filtered.itemCount(indexPath.section)
		cell.label.text = "\(section) (\(count))"
		
		return cell
	}
	
	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
		CGSize(width: view.frame.width, height: 50)
	}
}

class QuestionViewCell: UICollectionViewCell {
	let label = Label()
	
	let difficultyLabel = Label(text: "Easy")
	let difficultyIndicator = ColouredSquare()
	
	let categoryLabel = Label(text: "Arrays")
	
	let lock = IconView(systemIcon: "lock.circle.fill", color: .yellow)
	var lockWidthConstraint: NSLayoutConstraint!
	let circle = IconView(systemIcon: "circle", color: CodeComplete.theme.successColour)
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		
		translatesAutoresizingMaskIntoConstraints = false
		layer.cornerRadius = 16
		backgroundColor = CodeComplete.theme.secondary
		
		label.numberOfLines = 0
		label.textColor = CodeComplete.theme.textPrimary
		label.font = CodeComplete.theme.questionTitle
		difficultyLabel.textColor = CodeComplete.theme.textPrimary
		categoryLabel.textColor = .lightGray
		
		let difficulty = View()
		difficulty.addSubview(difficultyIndicator)
		difficulty.addSubview(difficultyLabel)
		
		addSubview(label)
		addSubview(difficulty)
		addSubview(categoryLabel)
		addSubview(lock)
		addSubview(circle)
		
		lockWidthConstraint = lock.widthAnchor.constraint(equalToConstant: 0)
		NSLayoutConstraint.activate([
			difficultyIndicator.heightAnchor.constraint(equalToConstant: 24),
			difficultyIndicator.widthAnchor.constraint(equalToConstant: 24),
			
			difficultyIndicator.topAnchor.constraint(equalTo: difficulty.topAnchor),
			difficultyIndicator.bottomAnchor.constraint(equalTo: difficulty.bottomAnchor),
			difficultyIndicator.leadingAnchor.constraint(equalTo: difficulty.leadingAnchor),
			difficultyLabel.topAnchor.constraint(equalTo: difficulty.topAnchor),
			difficultyLabel.bottomAnchor.constraint(equalTo: difficulty.bottomAnchor),
			difficultyLabel.trailingAnchor.constraint(equalTo: difficulty.trailingAnchor),
			difficultyLabel.leadingAnchor.constraint(equalTo: difficultyIndicator.trailingAnchor, constant: 8),
			
			difficulty.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
			difficulty.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
			difficulty.trailingAnchor.constraint(equalTo: trailingAnchor),
			
			label.topAnchor.constraint(equalTo: circle.bottomAnchor, constant: 8),
			label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
			label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
			
			categoryLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
			categoryLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
			categoryLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
			
			lock.topAnchor.constraint(equalTo: topAnchor, constant: 16),
			lock.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
			lockWidthConstraint,
			lock.heightAnchor.constraint(equalToConstant: 24),
			
			circle.topAnchor.constraint(equalTo: topAnchor, constant: 16),
			circle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
			circle.widthAnchor.constraint(equalToConstant: 24),
			circle.heightAnchor.constraint(equalToConstant: 24),
		])
	}
	
	func set(question: Questions, state: String?) {
		if state == nil {
			let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold, scale: .default)
			circle.image = UIImage(
				systemName: "circle",
				withConfiguration: config
			)!.withTintColor(
				CodeComplete.theme.successColour,
				renderingMode: .alwaysOriginal
			)
		} else if state != nil && state! == "success" {
			let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold, scale: .default)
			circle.image = UIImage(
				systemName: "circle.fill",
				withConfiguration: config
			)!.withTintColor(
				CodeComplete.theme.successColour,
				renderingMode: .alwaysOriginal
			)
		} else if state != nil && state! == "fail" {
			let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold, scale: .default)
			circle.image = UIImage(
				systemName: "circle.fill",
				withConfiguration: config
			)!.withTintColor(
				CodeComplete.theme.failedColour,
				renderingMode: .alwaysOriginal
			)
		}
		
		label.text = question.Name
		categoryLabel.text = "#\(question.Category.lowercased().split(separator: " ").joined(separator: ""))"
		
		if question.Difficulty == 1 {
			difficultyLabel.text = "Easy"
			difficultyIndicator.backgroundColor = UIColor(red: 126/255, green: 211/255, blue: 33/255, alpha: 1.0)
		} else if question.Difficulty == 2 {
			difficultyLabel.text = "Medium"
			difficultyIndicator.backgroundColor = UIColor(red: 74/255, green: 144/255, blue: 226/255, alpha: 1.0)
		} else if question.Difficulty == 3 {
			difficultyLabel.text = "Hard"
			difficultyIndicator.backgroundColor = UIColor(red: 208/255, green: 2/255, blue: 27/255, alpha: 1.0)
		} else if question.Difficulty == 4 {
			difficultyLabel.text = "Very Hard"
			difficultyIndicator.backgroundColor = UIColor(red: 144/255, green: 19/255, blue: 254/255, alpha: 1.0)
		} else {
			difficultyLabel.text = "Extremely Hard"
			difficultyIndicator.backgroundColor = .black
		}
	}
	
	func `is`(locked: Bool) {
		lockWidthConstraint.constant = locked ? 24 : 0
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class QuestionViewHeaderCell: UICollectionViewCell {
	let label = Label()
	
	override init(frame: CGRect) {
		super.init(frame: frame)
		
		backgroundColor = CodeComplete.theme.tertiary
		label.font = CodeComplete.theme.sectionTitle
		label.textColor = CodeComplete.theme.textPrimary
		
		addSubview(label)
		NSLayoutConstraint.activate([
			label.topAnchor.constraint(equalTo: topAnchor),
			label.bottomAnchor.constraint(equalTo: bottomAnchor),
			label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
			label.trailingAnchor.constraint(equalTo: trailingAnchor)
		])
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
