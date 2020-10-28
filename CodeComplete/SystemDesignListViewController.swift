//
//  ViewController.swift
//  CodeComplete
//
//  Copyright © 2020 Vijay Sharma. All rights reserved.
//

import UIKit
import Firebase

class SystemDesignListViewController: UIViewController {
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
		view.register(SystemDesignViewCell.self, forCellWithReuseIdentifier: "cell")
		
		return view
	}()
	
	private let questions: [SystemDesignQuestion]
	private let service: Service
	private let database: Database

	init(
		questions: [SystemDesignQuestion],
		service: Service,
		database: Database
	) {
		self.questions = questions
		self.service = service
		self.database = database
		super.init(nibName: nil, bundle: nil)
		
		view.backgroundColor = CodeComplete.theme.primary
		view.addSubview(collection)
		
		NSLayoutConstraint.activate([
			collection.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			collection.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
			collection.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
			collection.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
		])
		
//		NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
//		NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
	}
	
	public func refresh() {
		collection.reloadData()
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

extension SystemDesignListViewController: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		questions.count
	}
	
	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! SystemDesignViewCell

		let question = questions[indexPath.row]
		let state = database.state(name: question.name)
		cell.set(question: question, state: state)
		service.isLocked(name: question.name) { isLocked in
			cell.is(locked: isLocked)
		}
		
		return cell
	}
	
	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		collectionView.deselectItem(at: indexPath, animated: true)
		let controller = SystemDesignViewController(
			provider: DesignProvider(
				model: self.questions,
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
			return CGSize(width: fullWidth, height: 130)
		}
		let size = (fullWidthF - (CGFloat(possibleColumns - 1) * 16)) / CGFloat(possibleColumns)
		return CGSize(width: size, height: 130)
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
}

class SystemDesignViewCell: UICollectionViewCell {
	let label = Label()
	
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
		
		addSubview(label)
		addSubview(lock)
		addSubview(circle)
		
		lockWidthConstraint = lock.widthAnchor.constraint(equalToConstant: 0)
		NSLayoutConstraint.activate([
			label.topAnchor.constraint(equalTo: circle.bottomAnchor, constant: 8),
			label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
			label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
			
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
	
	func set(question: SystemDesignQuestion, state: String?) {
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
		
		label.text = question.name
	}
	
	func `is`(locked: Bool) {
		lockWidthConstraint.constant = locked ? 24 : 0
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
