//
//  Models.swift
//  CodeComplete
//
//  Copyright © 2020 Vijay Sharma. All rights reserved.
//

import Foundation

struct Metadata: Decodable {
	let number: Int
}

struct Questions: Decodable {
	let Name: String
	let Category: String
	let Difficulty: Int
	let Available: Bool
	let Metadata: Metadata
}

struct QuestionList: Decodable {
	let Problems: [Questions]
}

class QuestionSummary {
	private let data: [String: Any]
	init(data: [String: Any]) {
		self.data = data
	}
	
	lazy var Name: String = { [unowned self] in
		return self.data["Name"] as! String
	}()
	
	lazy var Category: String = { [unowned self] in
		return self.data["Category"] as! String
	}()
	
	lazy var Difficulty: Int  = { [unowned self] in
	   return self.data["Difficulty"] as! Int
	}()
	
	lazy var Available: Bool  = { [unowned self] in
		return self.data["Available"] as! Bool
	}()
}

class Resource {
	private let data: [String: Any]
	init(data: [String: Any]) {
		self.data = data
	}
	
	lazy var Language: String = { [unowned self] in
		return self.data["Language"] as! String
	}()
	
	lazy var StartingCode: String = { [unowned self] in
		return self.data["StartingCode"] as! String
	}()
	
	lazy var StartingTest: String = { [unowned self] in
		return self.data["StartingTest"] as! String
	}()
	
	lazy var SandboxCode: String = { [unowned self] in
		return self.data["SandboxCode"] as! String
	}()
	
	lazy var Solutions: [String] = { [unowned self] in
		let solutions = self.data["Solutions"] as! [String]
		return solutions
	}()
}

class Ressources {
	private let data: [String: Any]
	init(data: [String: Any]) {
		self.data = data
	}
	
	lazy var javascript: Resource = { [unowned self] in
		return Resource(data: self.data["javascript"] as! [String: Any])
	}()
}

class Question {
	private let data: [String: Any]
	init(data: [String: Any]) {
		self.data = data
	}
	
	lazy var PromptHTML: String = { [unowned self] in
		return self.data["PromptHTML"] as! String
	}()
	
	lazy var Hints: String = { [unowned self] in
		return self.data["Hints"] as! String
	}()
	
	lazy var SpaceTime: String = { [unowned self] in
		return self.data["SpaceTime"] as! String
	}()
	
	lazy var Summary: QuestionSummary = { [unowned self] in
		return QuestionSummary(data: self.data["Summary"] as! [String: Any])
	}()
	
	lazy var Resources: Ressources = { [unowned self] in
		return Ressources(data: self.data["Resources"] as! [String: Any])
	}()
	
	lazy var JSONTests: [String] = { [unowned self] in
		let stuff = self.data["JSONTests"] as! [Any]
		let tests = stuff.map { (item: Any) -> String in
			let data = try! JSONSerialization.data(withJSONObject: item, options: [])
			return String(data: data, encoding: .utf8)!
		}
		return tests
	}()
	
	lazy var JSONAnswers: [String] = { [unowned self] in
		let first = self.data["JSONAnswers"] as! [Any]
		let stuff = first[0] as! [Any]
		let answers = stuff.map { (item: Any) -> String in
			if (!JSONSerialization.isValidJSONObject(item)) {
				return "\(item)"
			}
			
			let data = try! JSONSerialization.data(withJSONObject: item, options: [])
			return String(data: data, encoding: .utf8)!
		}
		return answers
	}()
}

enum Group {
	case difficulty
	case category
}

struct QuestionsViewModel {
	private let questions: [String: [Questions]]
	private let sections: [String]
	private let group: Group
	
	var sectionCount: Int {
		get {
			return sections.count
		}
	}
	
	init(
		questions: [String: [Questions]],
		sections:[String],
		grouping: Group
	) {
		self.group = grouping
		self.questions = questions
		self.sections = sections
	}
	
	func itemCount(_ section: Int) -> Int {
		questions[self.sections[section]]?.count ?? 0
	}
	
	func get(section: Int, index: Int) -> Questions {
		return self.questions[self.sections[section]]![index]
	}
	
	func get(section: Int) -> String {
		if group == .difficulty {
			let difficulty = self.sections[section]
			if difficulty == "1" {
				return "Easy"
			} else if difficulty == "2" {
				return "Medium"
			} else if difficulty == "3" {
				return "Hard"
			} else if difficulty == "4" {
				return "Very Hard"
			} else {
				return "Extremely Hard"
			}
		} else {
			return self.sections[section]
		}
	}
}

struct TestResult {
	let name: String
	let success: Bool
	let message: String?
	let expected: Any?
	let actual: Any?
}

struct TestResults {
	let tests: [TestResult]
	let logs: [String]
}

struct Hint: Decodable {
	let question: String
	let answer: String
}

struct WalkthroughImage: Decodable {
	let name: String
	let `extension`: String
}

struct Walkthrough: Decodable {
	let title: String
	let content: String
	let image: WalkthroughImage?
}

struct SystemDesignQuestion: Decodable {
	let name: String
	let available: Bool
	let prompt: String
	let walkthrough: [Walkthrough]
	let hints: [Hint]
}

struct SystemDesignList: Decodable {
	let design: [SystemDesignQuestion]
}
