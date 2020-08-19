//
//  OnboardViewController.swift
//  CodeComplete
//
//  Copyright © 2020 Vijay Sharma. All rights reserved.
//

import Foundation

class OnboardingViewController: UIViewController {
	private let skippable: Bool
	var delegate: ((OnboardingViewController) -> Void)?
	
	init(skippable: Bool = true) {
		self.skippable = skippable
		super.init(nibName: nil, bundle: nil)
		view.backgroundColor = .white
		
		self.buildView()
	}
	
	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		super.viewWillTransition(to: size, with: coordinator)
		self.buildView()
	}
	
	private func buildView() {
		view.subviews.forEach { $0.removeFromSuperview() }
		
		let close = ImageButton(systemIcon: "xmark", padding: .zero)
		close.tintColor = .black
		close.action = {
			self.delegate?(self)
		}
		
		let notification = PortraitPageView(
			title: "Stay Up to Date",
			substitle: "If you want to be notified as we improve the app, or launch promotions, consider signing up for notifications.",
			image: UIImage(named: "code-complete-onboard-4")
		)
		let onboard = [
			PortraitPageView(
				title: "Welcome to Code Complete",
				substitle: "The ultimate resource to prepare for coding interviews. Everything you need, in one streamlined platform.",
				image: UIImage(named: "code-complete-onboard-1")
			),
			PortraitPageView(
				title: "Read. Write. Run.",
				substitle: "Coding out solutions to algorithm problems is the best way to practice. Our Javascript code-execution environment lets you type out your answers and run them against our test cases.",
				image: UIImage(named: "code-complete-onboard-2")
			),
			PortraitPageView(
				title: "Decide. Commit. Succeed.",
				substitle: "Many of our users have gotten offers from awesome companies. They all used Code Complete as the backbone for their technical coding interview preparation.",
				image: UIImage(named: "code-complete-onboard-3")
			),
			notification,
			PortraitPageView(
				title: "Help Make Code Complete Better.",
				substitle: "We're a small team of passionate engineers. We want to help people take control of their careers by helping them prepare for coding interviews. You can help improve the platform by providing feedback or leaving a review. Your contribution goes a long way to helping us help others.",
				image: UIImage(named: "code-complete-onboard-5"),
				nextButtonImage: "checkmark"
			),
		]
		
		let scroll = HorizontalPageView(content: onboard)
		
		let page = UIPageControl(frame: .zero)
		page.translatesAutoresizingMaskIntoConstraints = false
		page.currentPage = 0
		page.numberOfPages = onboard.count
		page.pageIndicatorTintColor = CodeComplete.theme.primary
		page.currentPageIndicatorTintColor = CodeComplete.theme.action
		page.isUserInteractionEnabled = false
		
		scroll.pageChanged = {
			page.currentPage = $0
		}
		for (index, item) in onboard.enumerated() {
			item.nextButton.action = {
				scroll.scrollToItem(at: IndexPath(item: index + 1, section: 0), at: .right, animated: true)
				page.currentPage = index + 1
			}
		}
		let previousNottificationAction = notification.nextButton.action
		notification.nextButton.action = {
			let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
			UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { authorized, _ in
				DispatchQueue.main.async {
					TestFairy.setAttribute("push-notification-enabled", withValue: authorized ? "yes" : "no")
					previousNottificationAction?()
				}
			}
		}
		
		onboard.last!.nextButton.action = {			
			self.delegate?(self)
		}
		
		view.addSubview(scroll)
		view.addSubview(page)
		
		if self.skippable {
			view.addSubview(close)
			NSLayoutConstraint.activate([
				close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
				close.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
				close.widthAnchor.constraint(equalToConstant: 48),
				close.heightAnchor.constraint(equalToConstant: 48),
			])
		}

		NSLayoutConstraint.activate([
			scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
			scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
			scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
			scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
			page.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
			page.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
			page.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
		])
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

class PortraitPageView: View {
	let nextButton: ActionImageButton
	
	init(
		title: String,
		substitle: String,
		image: UIImage?,
		nextButtonImage: String = "arrow.right"
	) {
		self.nextButton = ActionImageButton(systemIcon: nextButtonImage, padding: .zero)
		super.init()
		
		let pageTitle = Label(text: title)
		pageTitle.numberOfLines = 1
		pageTitle.textAlignment = .center
		pageTitle.font = CodeComplete.theme.questionTitle
		pageTitle.textColor = .black
		
		let pageSubtitle = Label(text: substitle)
		pageSubtitle.numberOfLines = 0
		pageSubtitle.textAlignment = .center
		pageSubtitle.textColor = .darkGray
		
		let pageImage = UIImageView(image: image)
		pageImage.translatesAutoresizingMaskIntoConstraints = false
		pageImage.contentMode = .scaleAspectFit
		
		let actionContainer = View()
		actionContainer.addSubview(nextButton)
		nextButton.layer.cornerRadius = 8
		
		let topView = View()
		topView.addSubview(pageImage)
		topView.fill(with: pageImage, padding: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
		
		let bottomView = View()
		bottomView.addSubview(pageTitle)
		bottomView.addSubview(pageSubtitle)
		bottomView.addSubview(actionContainer)
		
		addSubview(topView)
		addSubview(bottomView)
		
		NSLayoutConstraint.activate([
			topView.topAnchor.constraint(equalTo: topAnchor),
			topView.leadingAnchor.constraint(equalTo: leadingAnchor),
			topView.trailingAnchor.constraint(equalTo: trailingAnchor),
			topView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.5),
			
			bottomView.topAnchor.constraint(equalTo: topView.bottomAnchor),
			bottomView.leadingAnchor.constraint(equalTo: leadingAnchor),
			bottomView.trailingAnchor.constraint(equalTo: trailingAnchor),
			bottomView.bottomAnchor.constraint(equalTo: bottomAnchor),
			
			pageTitle.topAnchor.constraint(equalTo: bottomView.topAnchor, constant: 12),
			pageTitle.leadingAnchor.constraint(equalTo: bottomView.leadingAnchor, constant: 8),
			pageTitle.trailingAnchor.constraint(equalTo: bottomView.trailingAnchor, constant: -8),
			
			pageSubtitle.topAnchor.constraint(equalTo: pageTitle.bottomAnchor, constant: 12),
			pageSubtitle.leadingAnchor.constraint(equalTo: bottomView.leadingAnchor, constant: 8),
			pageSubtitle.trailingAnchor.constraint(equalTo: bottomView.trailingAnchor, constant: -8),
			
			actionContainer.topAnchor.constraint(equalTo: pageSubtitle.bottomAnchor),
			actionContainer.leadingAnchor.constraint(equalTo: bottomView.leadingAnchor),
			actionContainer.trailingAnchor.constraint(equalTo: bottomView.trailingAnchor),
			actionContainer.bottomAnchor.constraint(equalTo: bottomView.bottomAnchor),
			
			nextButton.widthAnchor.constraint(equalToConstant: 52),
			nextButton.heightAnchor.constraint(equalToConstant: 52),
			nextButton.trailingAnchor.constraint(equalTo: actionContainer.trailingAnchor, constant: -12),
			nextButton.bottomAnchor.constraint(equalTo: actionContainer.bottomAnchor, constant: -12),
		])
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
