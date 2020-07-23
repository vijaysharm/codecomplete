//
//  CodeEngine.swift
//  CodeComplete
//
//  Copyright © 2020 Vijay Sharma. All rights reserved.
//

import Foundation
import JavaScriptCore

enum EngineError: Error {
	case unknown
	case internalError(reason: String)
	case engineCreationException
	case executionException(reason: String?)
}

class CodeEngine {
	private let javascript = JavascriptCodeEngine()
	func run(
		code: String,
		question: Question,
		callback: @escaping (Result<TestResults, EngineError>) -> Void
	) {
		DispatchQueue.global(qos: .userInitiated).async {
			let result = self.javascript.run(code: code, question: question)
			DispatchQueue.main.async {
				callback(result)
			}
		}
	}
}

class JavascriptCodeEngine {
	private let chaiSource: String
	private var exception: EngineError?
	private let patcher = TestPatcher()
	
	init() {
		let bundle = Bundle(for: CodeEngine.self)
		let filepath = bundle.path(forResource: "chai", ofType: "js")!
		self.chaiSource = try! String.init(contentsOfFile: filepath)
	}
	
	func run(code: String, question: Question) -> Result<TestResults, EngineError> {
		guard let context = createJavascriptContext() else { return .failure(.engineCreationException) }
		context.exceptionHandler = { (context, exception) in
			if exception != nil, let reason = exception!.toString() {
				self.exception = .executionException(reason: reason)
			} else {
				self.exception = .executionException(reason: nil)
			}
		}
		
		let script = code
		let test = patcher.patch(question: question)
		
//		let script = """
//		function twoNumberSum(array, targetSum) {
//		  for (let i = 0; i < array.length - 1; i++) {
//			const firstNum = array[i];
//			for (let j = i + 1; j < array.length; j++) {
//			  const secondNum = array[j];
//			  if (firstNum + secondNum === targetSum) {
//				return [firstNum, secondNum];
//			  }
//			}
//		  }
//		  return [];
//		}
//		exports.twoNumberSum = twoNumberSum;
//		"""
		
		let require = createJSRequire(script, context)
		context.setObject(require, forKeyedSubscript: "require" as NSString)
		context.evaluateScript(test)
		
		if let exception = self.exception {
			return .failure(exception)
		}
		
		guard let results = context.objectForKeyedSubscript("results") else {
			return .failure(.internalError(reason: "Failed to get test results"))
		}
		guard let array = results.toArray() else {
			return .failure(.internalError(reason: "Failed to cast results to array"))
		}
		
		let testResults = array.map { (item: Any) -> TestResult in
			let data = item as! [String: Any]
			return TestResult(
				name: data["name"] as! String,
				success: data["success"] as! Bool,
				message: data["message"] as? String,
				expected: data["expected"],
				actual: data["actual"]
			)
		}
		let logs: [String] = context.objectForKeyedSubscript("logs")?.toArray().map { "\($0)" } ?? []
		
		return .success(TestResults(tests: testResults, logs: logs))
	}
	
	private func createJSRequire(_ code: String, _ context: JSContext) -> @convention(block) (String) -> (JSValue?) {
		let require: @convention(block) (String) -> (JSValue?) = { path in
			if path == "chai" {
				return self.importChai(context)
			} else if path == "./program" {
				return self.importProgram(code, context)
			} else {
				fatalError("Unsupported import \(path)")
			}
			
			return nil
		}
		
		return require
	}
	
	private func importChai(_ context: JSContext) -> JSValue? {
		let window = JSValue(newObjectIn: context)
		context.setObject(window, forKeyedSubscript: "window" as NSString)
		context.evaluateScript(self.chaiSource)
		
		return context.evaluateScript("window.Chai.chai")
	}
	
	private func importProgram(_ code: String, _ context: JSContext) -> JSValue? {
		return context.evaluateScript(
			"""
			(function () {
				var exports = {};
				\(code)
				return exports
			}());
			"""
		)
	}
	
	private func createJavascriptContext() -> JSContext? {
		guard let context = JSContext() else { return nil }
		
		let testLibrary = """
		var logs = [];
		var console = {
			log: function(message) { logs.push(message); },
			error: function(message) { logs.push(message); },
			warn: function(message) { logs.push(message); },
			trace: function(message) { logs.push(message); },
			info: function(message) { logs.push(message); },
			debug: function(message) { logs.push(message); },
		};
		var results = [];
		function it(description, test)  {
			var run = {name: description, success: false, message: null, actual: null, expected: null};
			try {
				console.log("---------- " + description + " ----------");
				test();
				run.success = true;
			} catch(exception) {
				console.log(exception.message);
				run.message = exception.message;
				run.actual = JSON.stringify(exception.actual);
				run.expected = JSON.stringify(exception.expected);
			}

			results.push(run);
		}
		"""
		context.evaluateScript(testLibrary)
		
		return context
	}
}

class JSONPrettyPrinter {
	private let context: JSContext
	
	init() {
		let bundle = Bundle(for: CodeEngine.self)
		let filepath = bundle.path(forResource: "json-stringify-pretty-compact", ofType: "js")!
		let source = try! String.init(contentsOfFile: filepath)
		
		self.context = JSContext()!
		self.context.evaluateScript("var module = {};\n\(source);")
	}
	
	func stringify(json: String) -> String {
		let result = context.evaluateScript("module.exports(\(json));")
		return result?.toString() ?? json
	}
}

class TestPatcher {
	func patch(question: Question) -> String {
		if let patch = patches[question.Summary.Name] {
			return patch
		}
		
		return question.Resources.javascript.StartingTest
	}
	
	private let patches: [String: String] = [
		"All Kinds Of Node Depths":
		"""
		const program = require('./program');
		const chai = require('chai');
		class BinaryTree {
		  constructor(value) {
			this.value = value;
			this.left = null;
			this.right = null;
		  }
		}
		it('Test Case #1', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  root.left.left = new BinaryTree(4);
		  root.left.left.left = new BinaryTree(8);
		  root.left.left.right = new BinaryTree(9);
		  root.left.right = new BinaryTree(5);
		  root.right = new BinaryTree(3);
		  root.right.left = new BinaryTree(6);
		  root.right.right = new BinaryTree(7);
		  const actual = program.allKindsOfNodeDepths(root);
		  chai.expect(actual).to.deep.equal(26);
		});
		it('Test Case #2', function () {
		  const root = new BinaryTree(1);
		  const actual = program.allKindsOfNodeDepths(root);
		  chai.expect(actual).to.deep.equal(0);
		});
		it('Test Case #3', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  const actual = program.allKindsOfNodeDepths(root);
		  chai.expect(actual).to.deep.equal(1);
		});
		it('Test Case #4', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  root.right = new BinaryTree(3);
		  const actual = program.allKindsOfNodeDepths(root);
		  chai.expect(actual).to.deep.equal(2);
		});
		it('Test Case #5', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  root.left.left = new BinaryTree(4);
		  root.right = new BinaryTree(3);
		  const actual = program.allKindsOfNodeDepths(root);
		  chai.expect(actual).to.deep.equal(5);
		});
		it('Test Case #6', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  root.left.left = new BinaryTree(3);
		  root.left.left.left = new BinaryTree(4);
		  root.left.left.left.left = new BinaryTree(5);
		  root.left.left.left.left.left = new BinaryTree(6);
		  root.left.left.left.left.left.right = new BinaryTree(7);
		  const actual = program.allKindsOfNodeDepths(root);
		  chai.expect(actual).to.deep.equal(56);
		});
		it('Test Case #7', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  root.left.left = new BinaryTree(3);
		  root.left.left.left = new BinaryTree(4);
		  root.left.left.left.left = new BinaryTree(5);
		  root.left.left.left.left.left = new BinaryTree(6);
		  root.left.left.left.left.left.right = new BinaryTree(7);
		  root.right = new BinaryTree(8);
		  root.right.right = new BinaryTree(9);
		  root.right.right.right = new BinaryTree(10);
		  root.right.right.right.right = new BinaryTree(11);
		  root.right.right.right.right.right = new BinaryTree(12);
		  root.right.right.right.right.right.left = new BinaryTree(13);
		  const actual = program.allKindsOfNodeDepths(root);
		  chai.expect(actual).to.deep.equal(112);
		});
		it('Test Case #8', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  root.left.left = new BinaryTree(4);
		  root.left.left.left = new BinaryTree(8);
		  root.left.left.right = new BinaryTree(9);
		  root.left.right = new BinaryTree(5);
		  root.right = new BinaryTree(3);
		  root.right.left = new BinaryTree(6);
		  root.right.left.left = new BinaryTree(10);
		  root.right.left.left.right = new BinaryTree(11);
		  root.right.left.left.right.left = new BinaryTree(12);
		  root.right.left.left.right.left.left = new BinaryTree(14);
		  root.right.left.left.right.right = new BinaryTree(13);
		  root.right.left.left.right.right.left = new BinaryTree(15);
		  root.right.left.left.right.right.right = new BinaryTree(16);
		  root.right.right = new BinaryTree(7);
		  const actual = program.allKindsOfNodeDepths(root);
		  chai.expect(actual).to.deep.equal(135);
		});
		it('Test Case #9', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  root.left.left = new BinaryTree(3);
		  root.left.left.left = new BinaryTree(4);
		  root.left.left.left.left = new BinaryTree(5);
		  root.left.left.left.left.left = new BinaryTree(6);
		  root.left.left.left.left.left.left = new BinaryTree(7);
		  root.left.left.left.left.left.left.left = new BinaryTree(8);
		  root.left.left.left.left.left.left.left.left = new BinaryTree(9);
		  const actual = program.allKindsOfNodeDepths(root);
		  chai.expect(actual).to.deep.equal(120);
		});
		""",
		
		"Binary Search": """
		const program = require('./program');
		const chai = require('chai');
		it('Test Case #1', function () {
			chai.expect(program.binarySearch([0,1,21,33,45,45,61,71,72,73], 33)).to.deep.equal(3);
		});
		it('Test Case #2', function () {
			chai.expect(program.binarySearch([1,5,23,111], 111)).to.deep.equal(3);
		});
		it('Test Case #3', function () {
			chai.expect(program.binarySearch([1,5,23,111], 5)).to.deep.equal(1);
		});
		it('Test Case #4', function () {
			chai.expect(program.binarySearch([1,5,23,111], 35)).to.deep.equal(-1);
		});
		it('Test Case #5', function () {
			chai.expect(program.binarySearch([0,1,21,33,45,45,61,71,72,73], 72)).to.deep.equal(8);
		});
		it('Test Case #6', function () {
			chai.expect(program.binarySearch([0,1,21,33,45,45,61,71,72,73], 73)).to.deep.equal(9);
		});
		it('Test Case #7', function () {
			chai.expect(program.binarySearch([0,1,21,33,45,45,61,71,72,73], 70)).to.deep.equal(-1);
		});
		it('Test Case #8', function () {
			chai.expect(program.binarySearch([0,1,21,33,45,45,61,71,72,73,355], 355)).to.deep.equal(10);
		});
		it('Test Case #9', function () {
			chai.expect(program.binarySearch([0,1,21,33,45,45,61,71,72,73,355], 354)).to.deep.equal(-1);
		});
		it('Test Case #10', function () {
			chai.expect(program.binarySearch([1,5,23,111], 120)).to.deep.equal(-1);
		});
		it('Test Case #11', function () {
			chai.expect(program.binarySearch([5,23,111], 3)).to.deep.equal(-1);
		});
		""",
		
		"Bubble Sort": """
		const program = require('./program');
		const chai = require('chai');
		it('Test Case #1', function () {
			const input = [8,5,2,9,5,6,3];
			chai.expect(program.bubbleSort(input)).to.deep.equal([2,3,5,5,6,8,9]);
		});
		it('Test Case #2', function () {
			const input = [1];
			chai.expect(program.bubbleSort(input)).to.deep.equal([1]);
		});
		it('Test Case #3', function () {
			const input = [1,2];
			chai.expect(program.bubbleSort(input)).to.deep.equal([1,2]);
		});
		it('Test Case #4', function () {
			const input = [2,1];
			chai.expect(program.bubbleSort(input)).to.deep.equal([1,2]);
		});
		it('Test Case #5', function () {
			const input = [1,3,2];
			chai.expect(program.bubbleSort(input)).to.deep.equal([1,2,3]);
		});
		it('Test Case #6', function () {
			const input = [3,1,2];
			chai.expect(program.bubbleSort(input)).to.deep.equal([1,2,3]);
		});
		it('Test Case #7', function () {
			const input = [1,2,3];
			chai.expect(program.bubbleSort(input)).to.deep.equal([1,2,3]);
		});
		it('Test Case #8', function () {
			const input = [-4,5,10,8,-10,-6,-4,-2,-5,3,5,-4,-5,-1,1,6,-7,-6,-7,8];
			chai.expect(program.bubbleSort(input)).to.deep.equal([-10,-7,-7,-6,-6,-5,-5,-4,-4,-4,-2,-1,1,3,5,5,6,8,8,10]);
		});
		it('Test Case #9', function () {
			const input = [-7,2,3,8,-10,4,-6,-10,-2,-7,10,5,2,9,-9,-5,3,8];
			chai.expect(program.bubbleSort(input)).to.deep.equal([-10,-10,-9,-7,-7,-6,-5,-2,2,2,3,3,4,5,8,8,9,10]);
		});
		it('Test Case #10', function () {
			const input = [8,-6,7,10,8,-1,6,2,4,-5,1,10,8,-10,-9,-10,8,9,-2,7,-2,4];
			chai.expect(program.bubbleSort(input)).to.deep.equal([-10,-10,-9,-6,-5,-2,-2,-1,1,2,4,4,6,7,7,8,8,8,8,9,10,10]);
		});
		it('Test Case #11', function () {
			const input = [5,-2,2,-8,3,-10,-6,-1,2,-2,9,1,1];
			chai.expect(program.bubbleSort(input)).to.deep.equal([-10,-8,-6,-2,-2,-1,1,1,2,2,3,5,9]);
		});
		it('Test Case #12', function () {
			const input = [2,-2,-6,-10,10,4,-8,-1,-8,-4,7,-4,0,9,-9,0,-9,-9,8,1,-4,4,8,5,1,5,0,0,2,-10];
			chai.expect(program.bubbleSort(input)).to.deep.equal([-10,-10,-9,-9,-9,-8,-8,-6,-4,-4,-4,-2,-1,0,0,0,0,1,1,2,2,4,4,5,5,7,8,8,9,10]);
		});
		it('Test Case #13', function () {
			const input = [4,1,5,0,-9,-3,-3,9,3,-4,-9,8,1,-3,-7,-4,-9,-1,-7,-2,-7,4];
			chai.expect(program.bubbleSort(input)).to.deep.equal([-9,-9,-9,-7,-7,-7,-4,-4,-3,-3,-3,-2,-1,0,1,1,3,4,4,5,8,9]);
		});
		it('Test Case #14', function () {
			const input = [427,787,222,996,-359,-614,246,230,107,-706,568,9,-246,12,-764,-212,-484,603,934,-848,-646,-991,661,-32,-348,-474,-439,-56,507,736,635,-171,-215,564,-710,710,565,892,970,-755,55,821,-3,-153,240,-160,-610,-583,-27,131];
			chai.expect(program.bubbleSort(input)).to.deep.equal([-991,-848,-764,-755,-710,-706,-646,-614,-610,-583,-484,-474,-439,-359,-348,-246,-215,-212,-171,-160,-153,-56,-32,-27,-3,9,12,55,107,131,222,230,240,246,427,507,564,565,568,603,635,661,710,736,787,821,892,934,970,996]);
		});
		it('Test Case #15', function () {
			const input = [991,-731,-882,100,280,-43,432,771,-581,180,-382,-998,847,80,-220,680,769,-75,-817,366,956,749,471,228,-435,-269,652,-331,-387,-657,-255,382,-216,-6,-163,-681,980,913,-169,972,-523,354,747,805,382,-827,-796,372,753,519,906];
			chai.expect(program.bubbleSort(input)).to.deep.equal([-998,-882,-827,-817,-796,-731,-681,-657,-581,-523,-435,-387,-382,-331,-269,-255,-220,-216,-169,-163,-75,-43,-6,80,100,180,228,280,354,366,372,382,382,432,471,519,652,680,747,749,753,769,771,805,847,906,913,956,972,980,991]);
		});
		it('Test Case #16', function () {
			const input = [384,-67,120,759,697,232,-7,-557,-772,-987,687,397,-763,-86,-491,947,921,421,825,-679,946,-562,-626,-898,204,776,-343,393,51,-796,-425,31,165,975,-720,878,-785,-367,-609,662,-79,-112,-313,-94,187,260,43,85,-746,612,67,-389,508,777,624,993,-581,34,444,-544,243,-995,432,-755,-978,515,-68,-559,489,732,-19,-489,737,924];
			chai.expect(program.bubbleSort(input)).to.deep.equal([-995,-987,-978,-898,-796,-785,-772,-763,-755,-746,-720,-679,-626,-609,-581,-562,-559,-557,-544,-491,-489,-425,-389,-367,-343,-313,-112,-94,-86,-79,-68,-67,-19,-7,31,34,43,51,67,85,120,165,187,204,232,243,260,384,393,397,421,432,444,489,508,515,612,624,662,687,697,732,737,759,776,777,825,878,921,924,946,947,975,993]);
		});
		it('Test Case #17', function () {
			const input = [544,-578,556,713,-655,-359,-810,-731,194,-531,-685,689,-279,-738,886,-54,-320,-500,738,445,-401,993,-753,329,-396,-924,-975,376,748,-356,972,459,399,669,-488,568,-702,551,763,-90,-249,-45,452,-917,394,195,-877,153,153,788,844,867,266,-739,904,-154,-947,464,343,-312,150,-656,528,61,94,-581];
			chai.expect(program.bubbleSort(input)).to.deep.equal([-975,-947,-924,-917,-877,-810,-753,-739,-738,-731,-702,-685,-656,-655,-581,-578,-531,-500,-488,-401,-396,-359,-356,-320,-312,-279,-249,-154,-90,-54,-45,61,94,150,153,153,194,195,266,329,343,376,394,399,445,452,459,464,528,544,551,556,568,669,689,713,738,748,763,788,844,867,886,904,972,993]);
		});
		it('Test Case #18', function () {
			const input = [-19,759,168,306,270,-602,558,-821,-599,328,753,-50,-568,268,-92,381,-96,730,629,678,-837,351,896,63,-85,437,-453,-991,294,-384,-628,-529,518,613,-319,-519,-220,-67,834,619,802,207,946,-904,295,718,-740,-557,-560,80,296,-90,401,407,798,254,154,387,434,491,228,307,268,505,-415,-976,676,-917,937,-609,593,-36,881,607,121,-373,915,-885,879,391,-158,588,-641,-937,986,949,-321];
			chai.expect(program.bubbleSort(input)).to.deep.equal([-991,-976,-937,-917,-904,-885,-837,-821,-740,-641,-628,-609,-602,-599,-568,-560,-557,-529,-519,-453,-415,-384,-373,-321,-319,-220,-158,-96,-92,-90,-85,-67,-50,-36,-19,63,80,121,154,168,207,228,254,268,268,270,294,295,296,306,307,328,351,381,387,391,401,407,434,437,491,505,518,558,588,593,607,613,619,629,676,678,718,730,753,759,798,802,834,879,881,896,915,937,946,949,986]);
		});
		it('Test Case #19', function () {
			const input = [-823,164,48,-987,323,399,-293,183,-908,-376,14,980,965,842,422,829,59,724,-415,-733,356,-855,-155,52,328,-544,-371,-160,-942,-51,700,-363,-353,-359,238,892,-730,-575,892,490,490,995,572,888,-935,919,-191,646,-120,125,-817,341,-575,372,-874,243,610,-36,-685,-337,-13,295,800,-950,-949,-257,631,-542,201,-796,157,950,540,-846,-265,746,355,-578,-441,-254,-941,-738,-469,-167,-420,-126,-410,59];
			chai.expect(program.bubbleSort(input)).to.deep.equal([-987,-950,-949,-942,-941,-935,-908,-874,-855,-846,-823,-817,-796,-738,-733,-730,-685,-578,-575,-575,-544,-542,-469,-441,-420,-415,-410,-376,-371,-363,-359,-353,-337,-293,-265,-257,-254,-191,-167,-160,-155,-126,-120,-51,-36,-13,14,48,52,59,59,125,157,164,183,201,238,243,295,323,328,341,355,356,372,399,422,490,490,540,572,610,631,646,700,724,746,800,829,842,888,892,892,919,950,965,980,995]);
		});
		""",
		
		"Calendar Matching": """
		const program = require('./program');
		const chai = require('chai');
		it('Test Case #1', function () {
			const calendar1 = [["9:00","10:30"],["12:00","13:00"],["16:00","18:00"]];
			const dailyBounds1 = ["9:00","20:00"]
			const calendar2 = [["10:00","11:30"],["12:30","14:30"],["14:30","15:00"],["16:00","17:00"]]
			const dailyBounds2 = ["10:00","18:30"]
			const meetingDuration = 30;
			const expected = [["11:30","12:00"],["15:00","16:00"],["18:00","18:30"]]
			const result = program.calendarMatching(calendar1, dailyBounds1, calendar2, dailyBounds2, meetingDuration);
			chai.expect(result).to.deep.equal(expected);
		});
		it('Test Case #2', function () {
			const calendar1 = [["9:00","10:30"],["12:00","13:00"],["16:00","18:00"]];
			const dailyBounds1 = ["9:00","20:00"]
			const calendar2 = [["10:00","11:30"],["12:30","14:30"],["14:30","15:00"],["16:00","17:00"]]
			const dailyBounds2 = ["10:00","18:30"]
			const meetingDuration = 30;
			const expected = [["11:30","12:00"],["15:00","16:00"],["18:00","18:30"]]
			const result = program.calendarMatching(calendar1, dailyBounds1, calendar2, dailyBounds2, meetingDuration);
			chai.expect(result).to.deep.equal(expected);
		});
		it('Test Case #3', function () {
			const calendar1 = [["9:00","10:30"],["12:00","13:00"],["16:00","18:00"]];
			const dailyBounds1 = ["9:00","20:00"]
			const calendar2 = [["10:00","11:30"],["12:30","14:30"],["14:30","15:00"],["16:00","17:00"]]
			const dailyBounds2 = ["10:00","18:30"]
			const meetingDuration = 45;
			const expected = [["15:00","16:00"]]
			const result = program.calendarMatching(calendar1, dailyBounds1, calendar2, dailyBounds2, meetingDuration);
			chai.expect(result).to.deep.equal(expected);
		});
		it('Test Case #4', function () {
			const calendar1 = [["9:00","10:30"],["12:00","13:00"],["16:00","18:00"]];
			const dailyBounds1 = ["8:00","20:00"]
			const calendar2 = [["10:00","11:30"],["12:30","14:30"],["14:30","15:00"],["16:00","17:00"]]
			const dailyBounds2 = ["7:00","18:30"]
			const meetingDuration = 45;
			const expected = [["8:00","9:00"],["15:00","16:00"]]
			const result = program.calendarMatching(calendar1, dailyBounds1, calendar2, dailyBounds2, meetingDuration);
			chai.expect(result).to.deep.equal(expected);
		});
		it('Test Case #5', function () {
			const calendar1 = [["8:00","10:30"],["11:30","13:00"],["14:00","16:00"],["16:00","18:00"]];
			const dailyBounds1 = ["8:00","18:00"]
			const calendar2 = [["10:00","11:30"],["12:30","14:30"],["14:30","15:00"],["16:00","17:00"]]
			const dailyBounds2 = ["7:00","18:30"]
			const meetingDuration = 15;
			const expected = []
			const result = program.calendarMatching(calendar1, dailyBounds1, calendar2, dailyBounds2, meetingDuration);
			chai.expect(result).to.deep.equal(expected);
		});
		it('Test Case #6', function () {
			const calendar1 = [["10:00","10:30"],["10:45","11:15"],["11:30","13:00"],["14:15","16:00"],["16:00","18:00"]];
			const dailyBounds1 = ["9:30","20:00"]
			const calendar2 = [["10:00","11:00"],["12:30","13:30"],["14:30","15:00"],["16:00","17:00"]]
			const dailyBounds2 = ["9:00","18:30"]
			const meetingDuration = 15;
			const expected = [["9:30","10:00"],["11:15","11:30"],["13:30","14:15"],["18:00","18:30"]]
			const result = program.calendarMatching(calendar1, dailyBounds1, calendar2, dailyBounds2, meetingDuration);
			chai.expect(result).to.deep.equal(expected);
		});
		it('Test Case #7', function () {
			const calendar1 = [["10:00","10:30"],["10:45","11:15"],["11:30","13:00"],["14:15","16:00"],["16:00","18:00"]];
			const dailyBounds1 = ["9:30","20:00"]
			const calendar2 = [["10:00","11:00"],["10:30","20:30"]]
			const dailyBounds2 = ["9:00","22:30"]
			const meetingDuration = 60;
			const expected = []
			const result = program.calendarMatching(calendar1, dailyBounds1, calendar2, dailyBounds2, meetingDuration);
			chai.expect(result).to.deep.equal(expected);
		});
		it('Test Case #8', function () {
			const calendar1 = [["10:00","10:30"],["10:45","11:15"],["11:30","13:00"],["14:15","16:00"],["16:00","18:00"]];
			const dailyBounds1 = ["9:30","20:00"]
			const calendar2 = [["10:00","11:00"],["10:30","16:30"]]
			const dailyBounds2 = ["9:00","22:30"]
			const meetingDuration = 60;
			const expected = [["18:00","20:00"]]
			const result = program.calendarMatching(calendar1, dailyBounds1, calendar2, dailyBounds2, meetingDuration);
			chai.expect(result).to.deep.equal(expected);
		});
		it('Test Case #9', function () {
			const calendar1 = [];
			const dailyBounds1 = ["9:30","20:00"]
			const calendar2 = []
			const dailyBounds2 = ["9:00","16:30"]
			const meetingDuration = 60;
			const expected = [["9:30","16:30"]]
			const result = program.calendarMatching(calendar1, dailyBounds1, calendar2, dailyBounds2, meetingDuration);
			chai.expect(result).to.deep.equal(expected);
		});
		it('Test Case #10', function () {
			const calendar1 = [];
			const dailyBounds1 = ["9:00","16:30"]
			const calendar2 = []
			const dailyBounds2 = ["9:30","20:00"]
			const meetingDuration = 60;
			const expected = [["9:30","16:30"]]
			const result = program.calendarMatching(calendar1, dailyBounds1, calendar2, dailyBounds2, meetingDuration);
			chai.expect(result).to.deep.equal(expected);
		});
		it('Test Case #11', function () {
			const calendar1 = [];
			const dailyBounds1 = ["9:30","16:30"]
			const calendar2 = []
			const dailyBounds2 = ["9:30","16:30"]
			const meetingDuration = 60;
			const expected = [["9:30","16:30"]]
			const result = program.calendarMatching(calendar1, dailyBounds1, calendar2, dailyBounds2, meetingDuration);
			chai.expect(result).to.deep.equal(expected);
		});
		it('Test Case #12', function () {
			const calendar1 = [["7:00","7:45"],["8:15","8:30"],["9:00","10:30"],["12:00","14:00"],["14:00","15:00"],["15:15","15:30"],["16:30","18:30"],["20:00","21:00"]];
			const dailyBounds1 = ["6:30","22:00"]
			const calendar2 = [["9:00","10:00"],["11:15","11:30"],["11:45","17:00"],["17:30","19:00"],["20:00","22:15"]]
			const dailyBounds2 = ["8:00","22:30"]
			const meetingDuration = 30;
			const expected = [["8:30","9:00"],["10:30","11:15"],["19:00","20:00"]]
			const result = program.calendarMatching(calendar1, dailyBounds1, calendar2, dailyBounds2, meetingDuration);
			chai.expect(result).to.deep.equal(expected);
		});
		""",
		
		"Branch Sums": """
		const program = require('./program');
		const chai = require('chai');
		class BinaryTree {
		  constructor(value) {
			this.value = value;
			this.left = null;
			this.right = null;
		  }
		}
		it('Test Case #1', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  root.left.left = new BinaryTree(4);
		  root.left.left.left = new BinaryTree(8);
		  root.left.left.right = new BinaryTree(9);
		  root.left.right = new BinaryTree(5);
		  root.left.right.left = new BinaryTree(10);
		  root.right = new BinaryTree(3);
		  root.right.left = new BinaryTree(6);
		  root.right.right = new BinaryTree(7);
		  const actual = program.branchSums(root);
		  chai.expect(actual).to.deep.equal([15,16,18,10,11]);
		});
		it('Test Case #2', function () {
		  const root = new BinaryTree(1);
		  const actual = program.branchSums(root);
		  chai.expect(actual).to.deep.equal([1]);
		});
		it('Test Case #3', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  const actual = program.branchSums(root);
		  chai.expect(actual).to.deep.equal([3]);
		});
		it('Test Case #4', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  root.right = new BinaryTree(3);
		  const actual = program.branchSums(root);
		  chai.expect(actual).to.deep.equal([3,4]);
		});
		it('Test Case #5', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  root.left.left = new BinaryTree(4);
		  root.left.right = new BinaryTree(5);
		  root.right = new BinaryTree(3);
		  const actual = program.branchSums(root);
		  chai.expect(actual).to.deep.equal([7,8,4]);
		});
		it('Test Case #6', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  root.left.left = new BinaryTree(4);
		  root.left.left.left = new BinaryTree(8);
		  root.left.left.right = new BinaryTree(9);
		  root.left.right = new BinaryTree(5);
		  root.left.right.left = new BinaryTree(10);
		  root.left.right.right = new BinaryTree(1);
		  root.right = new BinaryTree(3);
		  root.right.left = new BinaryTree(6);
		  root.right.left.left = new BinaryTree(1);
		  root.right.left.right = new BinaryTree(1);
		  root.right.right = new BinaryTree(7);
		  const actual = program.branchSums(root);
		  chai.expect(actual).to.deep.equal([15,16,18,9,11,11,11]);
		});
		it('Test Case #7', function () {
		  const root = new BinaryTree(0);
		  root.left = new BinaryTree(1);
		  root.left.left = new BinaryTree(10);
		  root.left.left.left = new BinaryTree(100);
		  const actual = program.branchSums(root);
		  chai.expect(actual).to.deep.equal([111]);
		});
		it('Test Case #8', function () {
		  const root = new BinaryTree(0);
		  root.right = new BinaryTree(1);
		  root.right.right = new BinaryTree(10);
		  root.right.right.right = new BinaryTree(100);
		  const actual = program.branchSums(root);
		  chai.expect(actual).to.deep.equal([111]);
		});
		it('Test Case #9', function () {
		  const root = new BinaryTree(0);
		  root.left = new BinaryTree(9);
		  root.right = new BinaryTree(1);
		  root.right.left = new BinaryTree(15);
		  root.right.right = new BinaryTree(10);
		  root.right.right.left = new BinaryTree(100);
		  root.right.right.right = new BinaryTree(200);
		  const actual = program.branchSums(root);
		  chai.expect(actual).to.deep.equal([9,16,111,211]);
		});
		""",
		
		"Continuous Median": """
		const program = require('./program');
		const chai = require('chai');
		it('Test Case #1', function () {
		  const handler = new program.ContinuousMedianHandler();
		  handler.insert(5);
		  handler.insert(10);
		  chai.expect(handler.getMedian()).to.deep.equal(7.5);
		  handler.insert(100);
		  chai.expect(handler.getMedian()).to.deep.equal(10);
		});
		it('Test Case #2', function () {
		  const handler = new program.ContinuousMedianHandler();
		  handler.insert(5);
		  chai.expect(handler.getMedian()).to.deep.equal(5);
		  handler.insert(10);
		  chai.expect(handler.getMedian()).to.deep.equal(7.5);
		});
		it('Test Case #3', function () {
		  const handler = new program.ContinuousMedianHandler();
		  handler.insert(5);
		  handler.insert(10);
		  handler.insert(100);
		  chai.expect(handler.getMedian()).to.deep.equal(10);
		  handler.insert(200);
		  chai.expect(handler.getMedian()).to.deep.equal(55);
		});
		it('Test Case #4', function () {
		  const handler = new program.ContinuousMedianHandler();
		  handler.insert(5);
		  handler.insert(10);
		  handler.insert(100);
		  handler.insert(200);
		  handler.insert(6);
		  chai.expect(handler.getMedian()).to.deep.equal(10);
		  handler.insert(13);
		  chai.expect(handler.getMedian()).to.deep.equal(11.5);
		});
		it('Test Case #5', function () {
		  const handler = new program.ContinuousMedianHandler();
		  handler.insert(5);
		  handler.insert(10);
		  handler.insert(100);
		  handler.insert(200);
		  handler.insert(6);
		  handler.insert(13);
		  handler.insert(14);
		  chai.expect(handler.getMedian()).to.deep.equal(13);
		  handler.insert(50);
		  chai.expect(handler.getMedian()).to.deep.equal(13.5);
		});
		it('Test Case #6', function () {
		  const handler = new program.ContinuousMedianHandler();
		  handler.insert(5);
		  handler.insert(10);
		  handler.insert(100);
		  handler.insert(200);
		  handler.insert(6);
		  handler.insert(13);
		  handler.insert(14);
		  handler.insert(50);
		  handler.insert(51);
		  chai.expect(handler.getMedian()).to.deep.equal(14);
		  handler.insert(52);
		  chai.expect(handler.getMedian()).to.deep.equal(32);
		});
		it('Test Case #7', function () {
		  const handler = new program.ContinuousMedianHandler();
		  handler.insert(5);
		  handler.insert(10);
		  handler.insert(100);
		  handler.insert(200);
		  handler.insert(6);
		  handler.insert(13);
		  handler.insert(14);
		  handler.insert(50);
		  handler.insert(51);
		  handler.insert(52);
		  handler.insert(1000);
		  chai.expect(handler.getMedian()).to.deep.equal(50);
		  handler.insert(10000);
		  chai.expect(handler.getMedian()).to.deep.equal(50.5);
		});
		it('Test Case #8', function () {
		  const handler = new program.ContinuousMedianHandler();
		  handler.insert(5);
		  handler.insert(10);
		  handler.insert(100);
		  handler.insert(200);
		  handler.insert(6);
		  handler.insert(13);
		  handler.insert(14);
		  handler.insert(50);
		  handler.insert(51);
		  handler.insert(52);
		  handler.insert(1000);
		  handler.insert(10000);
		  handler.insert(10001);
		  chai.expect(handler.getMedian()).to.deep.equal(51);
		  handler.insert(10002);
		  chai.expect(handler.getMedian()).to.deep.equal(51.5);
		});
		it('Test Case #9', function () {
		  const handler = new program.ContinuousMedianHandler();
		  handler.insert(5);
		  handler.insert(10);
		  handler.insert(100);
		  handler.insert(200);
		  handler.insert(6);
		  handler.insert(13);
		  handler.insert(14);
		  handler.insert(50);
		  handler.insert(51);
		  handler.insert(52);
		  handler.insert(1000);
		  handler.insert(10000);
		  handler.insert(10001);
		  handler.insert(10002);
		  handler.insert(10003);
		  chai.expect(handler.getMedian()).to.deep.equal(52);
		  handler.insert(10004);
		  chai.expect(handler.getMedian()).to.deep.equal(76);
		});
		it('Test Case #10', function () {
		  const handler = new program.ContinuousMedianHandler();
		  handler.insert(5);
		  handler.insert(10);
		  handler.insert(100);
		  handler.insert(200);
		  handler.insert(6);
		  handler.insert(13);
		  handler.insert(14);
		  handler.insert(50);
		  handler.insert(51);
		  handler.insert(52);
		  handler.insert(1000);
		  handler.insert(10000);
		  handler.insert(10001);
		  handler.insert(10002);
		  handler.insert(10003);
		  handler.insert(10004);
		  handler.insert(75);
		  chai.expect(handler.getMedian()).to.deep.equal(75);
		  handler.insert(80);
		  chai.expect(handler.getMedian()).to.deep.equal(77.5);
		});
		""",
		
		"Disk Stacking": """
		const program = require('./program');
		const chai = require('chai');
		it('Test Case #1', function () {
		  chai.expect(program.diskStacking([[2,1,2],[3,2,3],[2,2,8],[2,3,4],[1,3,1],[4,4,5]])).to.deep.equal([[2,1,2],[3,2,3],[4,4,5]]);
		});
		it('Test Case #2', function () {
		  chai.expect(program.diskStacking([[2,1,2]])).to.deep.equal([[2,1,2]]);
		});
		it('Test Case #3', function () {
		  chai.expect(program.diskStacking([[2,1,2],[3,2,3]])).to.deep.equal([[2,1,2],[3,2,3]]);
		});
		it('Test Case #4', function () {
		  chai.expect(program.diskStacking([[2,1,2],[3,2,3],[2,2,8]])).to.deep.equal([[2,2,8]]);
		});
		it('Test Case #5', function () {
		  chai.expect(program.diskStacking([[2,1,2],[3,2,3],[2,3,4]])).to.deep.equal([[2,1,2],[3,2,3]]);
		});
		it('Test Case #6', function () {
		  chai.expect(program.diskStacking([[2,1,2],[3,2,3],[2,2,8],[2,3,4],[2,2,1],[4,4,5]])).to.deep.equal([[2,1,2],[3,2,3],[4,4,5]]);
		});
		it('Test Case #7', function () {
		  chai.expect(program.diskStacking([[2,1,2],[3,2,5],[2,2,8],[2,3,4],[2,2,1],[4,4,5]])).to.deep.equal([[2,3,4],[4,4,5]]);
		});
		it('Test Case #8', function () {
		  chai.expect(program.diskStacking([[2,1,2],[3,2,3],[2,2,8],[2,3,4],[1,2,1],[4,4,5],[1,1,4]])).to.deep.equal([[1,1,4],[2,2,8]]);
		});
		it('Test Case #9', function () {
		  chai.expect(program.diskStacking([[3,3,4],[2,1,2],[3,2,3],[2,2,8],[2,3,4],[5,5,6],[1,2,1],[4,4,5],[1,1,4],[2,2,3]])).to.deep.equal([[2,2,3],[3,3,4],[4,4,5],[5,5,6]]);
		});
		""",
		
		"Find Closest Value In BST": """
		const program = require('./program');
		const chai = require('chai');
		class BinaryTree {
		  constructor(value) {
			this.value = value;
			this.left = null;
			this.right = null;
		  }
		}
		it('Test Case #1', function () {
		  const root = new BinaryTree(10);
		  root.left = new BinaryTree(5);
		  root.left.left = new BinaryTree(2);
		  root.left.left.left = new BinaryTree(1);
		  root.left.right = new BinaryTree(5);
		  root.right = new BinaryTree(15);
		  root.right.left = new BinaryTree(13);
		  root.right.left.right = new BinaryTree(14);
		  root.right.right = new BinaryTree(22);
		  const expected = 13;
		  const actual = program.findClosestValueInBst(root, 12);
		  chai.expect(actual).to.deep.equal(expected);
		});
		it('Test Case #2', function () {
		  const root = new BinaryTree(100);
		  root.left = new BinaryTree(5);
		  root.left.left = new BinaryTree(2);
		  root.left.left.left = new BinaryTree(1);
		  root.left.left.left.left = new BinaryTree(-51);
		  root.left.left.left.left.left = new BinaryTree(-403);
		  root.left.left.left.right = new BinaryTree(1);
		  root.left.left.left.right.right = new BinaryTree(1);
		  root.left.left.left.right.right.right = new BinaryTree(1);
		  root.left.left.left.right.right.right.right = new BinaryTree(1);
		  root.left.left.right = new BinaryTree(3);
		  root.left.right = new BinaryTree(15);
		  root.left.right.left = new BinaryTree(5);
		  root.left.right.right = new BinaryTree(22);
		  root.left.right.right.right = new BinaryTree(57);
		  root.left.right.right.right.right = new BinaryTree(60);
		  root.right = new BinaryTree(502);
		  root.right.left = new BinaryTree(204);
		  root.right.left.left = new BinaryTree(203);
		  root.right.left.right = new BinaryTree(205);
		  root.right.left.right.right = new BinaryTree(207);
		  root.right.left.right.right.left = new BinaryTree(206);
		  root.right.left.right.right.right = new BinaryTree(208);
		  root.right.right = new BinaryTree(55000);
		  root.right.right.left = new BinaryTree(1001);
		  root.right.right.left.right = new BinaryTree(4500);
		  const expected = 100;
		  const actual = program.findClosestValueInBst(root, 100);
		  chai.expect(actual).to.deep.equal(expected);
		});
		it('Test Case #3', function () {
		  const root = new BinaryTree(100);
		  root.left = new BinaryTree(5);
		  root.left.left = new BinaryTree(2);
		  root.left.left.left = new BinaryTree(1);
		  root.left.left.left.left = new BinaryTree(-51);
		  root.left.left.left.left.left = new BinaryTree(-403);
		  root.left.left.left.right = new BinaryTree(1);
		  root.left.left.left.right.right = new BinaryTree(1);
		  root.left.left.left.right.right.right = new BinaryTree(1);
		  root.left.left.left.right.right.right.right = new BinaryTree(1);
		  root.left.left.right = new BinaryTree(3);
		  root.left.right = new BinaryTree(15);
		  root.left.right.left = new BinaryTree(5);
		  root.left.right.right = new BinaryTree(22);
		  root.left.right.right.right = new BinaryTree(57);
		  root.left.right.right.right.right = new BinaryTree(60);
		  root.right = new BinaryTree(502);
		  root.right.left = new BinaryTree(204);
		  root.right.left.left = new BinaryTree(203);
		  root.right.left.right = new BinaryTree(205);
		  root.right.left.right.right = new BinaryTree(207);
		  root.right.left.right.right.left = new BinaryTree(206);
		  root.right.left.right.right.right = new BinaryTree(208);
		  root.right.right = new BinaryTree(55000);
		  root.right.right.left = new BinaryTree(1001);
		  root.right.right.left.right = new BinaryTree(4500);
		  const expected = 208;
		  const actual = program.findClosestValueInBst(root, 208);
		  chai.expect(actual).to.deep.equal(expected);
		});
		it('Test Case #4', function () {
		  const root = new BinaryTree(100);
		  root.left = new BinaryTree(5);
		  root.left.left = new BinaryTree(2);
		  root.left.left.left = new BinaryTree(1);
		  root.left.left.left.left = new BinaryTree(-51);
		  root.left.left.left.left.left = new BinaryTree(-403);
		  root.left.left.left.right = new BinaryTree(1);
		  root.left.left.left.right.right = new BinaryTree(1);
		  root.left.left.left.right.right.right = new BinaryTree(1);
		  root.left.left.left.right.right.right.right = new BinaryTree(1);
		  root.left.left.right = new BinaryTree(3);
		  root.left.right = new BinaryTree(15);
		  root.left.right.left = new BinaryTree(5);
		  root.left.right.right = new BinaryTree(22);
		  root.left.right.right.right = new BinaryTree(57);
		  root.left.right.right.right.right = new BinaryTree(60);
		  root.right = new BinaryTree(502);
		  root.right.left = new BinaryTree(204);
		  root.right.left.left = new BinaryTree(203);
		  root.right.left.right = new BinaryTree(205);
		  root.right.left.right.right = new BinaryTree(207);
		  root.right.left.right.right.left = new BinaryTree(206);
		  root.right.left.right.right.right = new BinaryTree(208);
		  root.right.right = new BinaryTree(55000);
		  root.right.right.left = new BinaryTree(1001);
		  root.right.right.left.right = new BinaryTree(4500);
		  const expected = 4500;
		  const actual = program.findClosestValueInBst(root, 4500);
		  chai.expect(actual).to.deep.equal(expected);
		});
		it('Test Case #5', function () {
		  const root = new BinaryTree(100);
		  root.left = new BinaryTree(5);
		  root.left.left = new BinaryTree(2);
		  root.left.left.left = new BinaryTree(1);
		  root.left.left.left.left = new BinaryTree(-51);
		  root.left.left.left.left.left = new BinaryTree(-403);
		  root.left.left.left.right = new BinaryTree(1);
		  root.left.left.left.right.right = new BinaryTree(1);
		  root.left.left.left.right.right.right = new BinaryTree(1);
		  root.left.left.left.right.right.right.right = new BinaryTree(1);
		  root.left.left.right = new BinaryTree(3);
		  root.left.right = new BinaryTree(15);
		  root.left.right.left = new BinaryTree(5);
		  root.left.right.right = new BinaryTree(22);
		  root.left.right.right.right = new BinaryTree(57);
		  root.left.right.right.right.right = new BinaryTree(60);
		  root.right = new BinaryTree(502);
		  root.right.left = new BinaryTree(204);
		  root.right.left.left = new BinaryTree(203);
		  root.right.left.right = new BinaryTree(205);
		  root.right.left.right.right = new BinaryTree(207);
		  root.right.left.right.right.left = new BinaryTree(206);
		  root.right.left.right.right.right = new BinaryTree(208);
		  root.right.right = new BinaryTree(55000);
		  root.right.right.left = new BinaryTree(1001);
		  root.right.right.left.right = new BinaryTree(4500);
		  const expected = 4500;
		  const actual = program.findClosestValueInBst(root, 4501);
		  chai.expect(actual).to.deep.equal(expected);
		});
		it('Test Case #6', function () {
		  const root = new BinaryTree(100);
		  root.left = new BinaryTree(5);
		  root.left.left = new BinaryTree(2);
		  root.left.left.left = new BinaryTree(1);
		  root.left.left.left.left = new BinaryTree(-51);
		  root.left.left.left.left.left = new BinaryTree(-403);
		  root.left.left.left.right = new BinaryTree(1);
		  root.left.left.left.right.right = new BinaryTree(1);
		  root.left.left.left.right.right.right = new BinaryTree(1);
		  root.left.left.left.right.right.right.right = new BinaryTree(1);
		  root.left.left.right = new BinaryTree(3);
		  root.left.right = new BinaryTree(15);
		  root.left.right.left = new BinaryTree(5);
		  root.left.right.right = new BinaryTree(22);
		  root.left.right.right.right = new BinaryTree(57);
		  root.left.right.right.right.right = new BinaryTree(60);
		  root.right = new BinaryTree(502);
		  root.right.left = new BinaryTree(204);
		  root.right.left.left = new BinaryTree(203);
		  root.right.left.right = new BinaryTree(205);
		  root.right.left.right.right = new BinaryTree(207);
		  root.right.left.right.right.left = new BinaryTree(206);
		  root.right.left.right.right.right = new BinaryTree(208);
		  root.right.right = new BinaryTree(55000);
		  root.right.right.left = new BinaryTree(1001);
		  root.right.right.left.right = new BinaryTree(4500);
		  const expected = -51;
		  const actual = program.findClosestValueInBst(root, -70);
		  chai.expect(actual).to.deep.equal(expected);
		});
		it('Test Case #7', function () {
		  const root = new BinaryTree(100);
		  root.left = new BinaryTree(5);
		  root.left.left = new BinaryTree(2);
		  root.left.left.left = new BinaryTree(1);
		  root.left.left.left.left = new BinaryTree(-51);
		  root.left.left.left.left.left = new BinaryTree(-403);
		  root.left.left.left.right = new BinaryTree(1);
		  root.left.left.left.right.right = new BinaryTree(1);
		  root.left.left.left.right.right.right = new BinaryTree(1);
		  root.left.left.left.right.right.right.right = new BinaryTree(1);
		  root.left.left.right = new BinaryTree(3);
		  root.left.right = new BinaryTree(15);
		  root.left.right.left = new BinaryTree(5);
		  root.left.right.right = new BinaryTree(22);
		  root.left.right.right.right = new BinaryTree(57);
		  root.left.right.right.right.right = new BinaryTree(60);
		  root.right = new BinaryTree(502);
		  root.right.left = new BinaryTree(204);
		  root.right.left.left = new BinaryTree(203);
		  root.right.left.right = new BinaryTree(205);
		  root.right.left.right.right = new BinaryTree(207);
		  root.right.left.right.right.left = new BinaryTree(206);
		  root.right.left.right.right.right = new BinaryTree(208);
		  root.right.right = new BinaryTree(55000);
		  root.right.right.left = new BinaryTree(1001);
		  root.right.right.left.right = new BinaryTree(4500);
		  const expected = 1001;
		  const actual = program.findClosestValueInBst(root, 2000);
		  chai.expect(actual).to.deep.equal(expected);
		});
		it('Test Case #8', function () {
		  const root = new BinaryTree(100);
		  root.left = new BinaryTree(5);
		  root.left.left = new BinaryTree(2);
		  root.left.left.left = new BinaryTree(1);
		  root.left.left.left.left = new BinaryTree(-51);
		  root.left.left.left.left.left = new BinaryTree(-403);
		  root.left.left.left.right = new BinaryTree(1);
		  root.left.left.left.right.right = new BinaryTree(1);
		  root.left.left.left.right.right.right = new BinaryTree(1);
		  root.left.left.left.right.right.right.right = new BinaryTree(1);
		  root.left.left.right = new BinaryTree(3);
		  root.left.right = new BinaryTree(15);
		  root.left.right.left = new BinaryTree(5);
		  root.left.right.right = new BinaryTree(22);
		  root.left.right.right.right = new BinaryTree(57);
		  root.left.right.right.right.right = new BinaryTree(60);
		  root.right = new BinaryTree(502);
		  root.right.left = new BinaryTree(204);
		  root.right.left.left = new BinaryTree(203);
		  root.right.left.right = new BinaryTree(205);
		  root.right.left.right.right = new BinaryTree(207);
		  root.right.left.right.right.left = new BinaryTree(206);
		  root.right.left.right.right.right = new BinaryTree(208);
		  root.right.right = new BinaryTree(55000);
		  root.right.right.left = new BinaryTree(1001);
		  root.right.right.left.right = new BinaryTree(4500);
		  const expected = 5;
		  const actual = program.findClosestValueInBst(root, 6);
		  chai.expect(actual).to.deep.equal(expected);
		});
		it('Test Case #9', function () {
		  const root = new BinaryTree(100);
		  root.left = new BinaryTree(5);
		  root.left.left = new BinaryTree(2);
		  root.left.left.left = new BinaryTree(1);
		  root.left.left.left.left = new BinaryTree(-51);
		  root.left.left.left.left.left = new BinaryTree(-403);
		  root.left.left.left.right = new BinaryTree(1);
		  root.left.left.left.right.right = new BinaryTree(1);
		  root.left.left.left.right.right.right = new BinaryTree(1);
		  root.left.left.left.right.right.right.right = new BinaryTree(1);
		  root.left.left.right = new BinaryTree(3);
		  root.left.right = new BinaryTree(15);
		  root.left.right.left = new BinaryTree(5);
		  root.left.right.right = new BinaryTree(22);
		  root.left.right.right.right = new BinaryTree(57);
		  root.left.right.right.right.right = new BinaryTree(60);
		  root.right = new BinaryTree(502);
		  root.right.left = new BinaryTree(204);
		  root.right.left.left = new BinaryTree(203);
		  root.right.left.right = new BinaryTree(205);
		  root.right.left.right.right = new BinaryTree(207);
		  root.right.left.right.right.left = new BinaryTree(206);
		  root.right.left.right.right.right = new BinaryTree(208);
		  root.right.right = new BinaryTree(55000);
		  root.right.right.left = new BinaryTree(1001);
		  root.right.right.left.right = new BinaryTree(4500);
		  const expected = 55000;
		  const actual = program.findClosestValueInBst(root, 30000);
		  chai.expect(actual).to.deep.equal(expected);
		});
		it('Test Case #10', function () {
		  const root = new BinaryTree(100);
		  root.left = new BinaryTree(5);
		  root.left.left = new BinaryTree(2);
		  root.left.left.left = new BinaryTree(1);
		  root.left.left.left.left = new BinaryTree(-51);
		  root.left.left.left.left.left = new BinaryTree(-403);
		  root.left.left.left.right = new BinaryTree(1);
		  root.left.left.left.right.right = new BinaryTree(1);
		  root.left.left.left.right.right.right = new BinaryTree(1);
		  root.left.left.left.right.right.right.right = new BinaryTree(1);
		  root.left.left.right = new BinaryTree(3);
		  root.left.right = new BinaryTree(15);
		  root.left.right.left = new BinaryTree(5);
		  root.left.right.right = new BinaryTree(22);
		  root.left.right.right.right = new BinaryTree(57);
		  root.left.right.right.right.right = new BinaryTree(60);
		  root.right = new BinaryTree(502);
		  root.right.left = new BinaryTree(204);
		  root.right.left.left = new BinaryTree(203);
		  root.right.left.right = new BinaryTree(205);
		  root.right.left.right.right = new BinaryTree(207);
		  root.right.left.right.right.left = new BinaryTree(206);
		  root.right.left.right.right.right = new BinaryTree(208);
		  root.right.right = new BinaryTree(55000);
		  root.right.right.left = new BinaryTree(1001);
		  root.right.right.left.right = new BinaryTree(4500);
		  const expected = 1;
		  const actual = program.findClosestValueInBst(root, -1);
		  chai.expect(actual).to.deep.equal(expected);
		});
		it('Test Case #11', function () {
		  const root = new BinaryTree(100);
		  root.left = new BinaryTree(5);
		  root.left.left = new BinaryTree(2);
		  root.left.left.left = new BinaryTree(1);
		  root.left.left.left.left = new BinaryTree(-51);
		  root.left.left.left.left.left = new BinaryTree(-403);
		  root.left.left.left.right = new BinaryTree(1);
		  root.left.left.left.right.right = new BinaryTree(1);
		  root.left.left.left.right.right.right = new BinaryTree(1);
		  root.left.left.left.right.right.right.right = new BinaryTree(1);
		  root.left.left.right = new BinaryTree(3);
		  root.left.right = new BinaryTree(15);
		  root.left.right.left = new BinaryTree(5);
		  root.left.right.right = new BinaryTree(22);
		  root.left.right.right.right = new BinaryTree(57);
		  root.left.right.right.right.right = new BinaryTree(60);
		  root.right = new BinaryTree(502);
		  root.right.left = new BinaryTree(204);
		  root.right.left.left = new BinaryTree(203);
		  root.right.left.right = new BinaryTree(205);
		  root.right.left.right.right = new BinaryTree(207);
		  root.right.left.right.right.left = new BinaryTree(206);
		  root.right.left.right.right.right = new BinaryTree(208);
		  root.right.right = new BinaryTree(55000);
		  root.right.right.left = new BinaryTree(1001);
		  root.right.right.left.right = new BinaryTree(4500);
		  const expected = 55000;
		  const actual = program.findClosestValueInBst(root, 29751);
		  chai.expect(actual).to.deep.equal(expected);
		});
		it('Test Case #12', function () {
		  const root = new BinaryTree(100);
		  root.left = new BinaryTree(5);
		  root.left.left = new BinaryTree(2);
		  root.left.left.left = new BinaryTree(1);
		  root.left.left.left.left = new BinaryTree(-51);
		  root.left.left.left.left.left = new BinaryTree(-403);
		  root.left.left.left.right = new BinaryTree(1);
		  root.left.left.left.right.right = new BinaryTree(1);
		  root.left.left.left.right.right.right = new BinaryTree(1);
		  root.left.left.left.right.right.right.right = new BinaryTree(1);
		  root.left.left.right = new BinaryTree(3);
		  root.left.right = new BinaryTree(15);
		  root.left.right.left = new BinaryTree(5);
		  root.left.right.right = new BinaryTree(22);
		  root.left.right.right.right = new BinaryTree(57);
		  root.left.right.right.right.right = new BinaryTree(60);
		  root.right = new BinaryTree(502);
		  root.right.left = new BinaryTree(204);
		  root.right.left.left = new BinaryTree(203);
		  root.right.left.right = new BinaryTree(205);
		  root.right.left.right.right = new BinaryTree(207);
		  root.right.left.right.right.left = new BinaryTree(206);
		  root.right.left.right.right.right = new BinaryTree(208);
		  root.right.right = new BinaryTree(55000);
		  root.right.right.left = new BinaryTree(1001);
		  root.right.right.left.right = new BinaryTree(4500);
		  const expected = 4500;
		  const actual = program.findClosestValueInBst(root, 29749);
		  chai.expect(actual).to.deep.equal(expected);
		});
		""",
		
		"Node Depths": """
		const program = require('./program');
		const chai = require('chai');
		class BinaryTree {
		  constructor(value) {
			this.value = value;
			this.left = null;
			this.right = null;
		  }
		}
		it('Test Case #1', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  root.left.left = new BinaryTree(4);
		  root.left.left.left = new BinaryTree(8);
		  root.left.left.right = new BinaryTree(9);
		  root.left.right = new BinaryTree(5);
		  root.right = new BinaryTree(3);
		  root.right.left = new BinaryTree(6);
		  root.right.right = new BinaryTree(7);
		  const actual = program.nodeDepths(root);
		  chai.expect(actual).to.deep.equal(16);
		});
		it('Test Case #2', function () {
		  const root = new BinaryTree(1);
		  const actual = program.nodeDepths(root);
		  chai.expect(actual).to.deep.equal(0);
		});
		it('Test Case #3', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  const actual = program.nodeDepths(root);
		  chai.expect(actual).to.deep.equal(1);
		});
		it('Test Case #4', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  root.right = new BinaryTree(3);
		  const actual = program.nodeDepths(root);
		  chai.expect(actual).to.deep.equal(2);
		});
		it('Test Case #5', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  root.left.left = new BinaryTree(4);
		  root.right = new BinaryTree(3);
		  const actual = program.nodeDepths(root);
		  chai.expect(actual).to.deep.equal(4);
		});
		it('Test Case #6', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  root.left.left = new BinaryTree(3);
		  root.left.left.left = new BinaryTree(4);
		  root.left.left.left.left = new BinaryTree(5);
		  root.left.left.left.left.left = new BinaryTree(6);
		  root.left.left.left.left.left.right = new BinaryTree(7);
		  const actual = program.nodeDepths(root);
		  chai.expect(actual).to.deep.equal(21);
		});
		it('Test Case #7', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  root.left.left = new BinaryTree(3);
		  root.left.left.left = new BinaryTree(4);
		  root.left.left.left.left = new BinaryTree(5);
		  root.left.left.left.left.left = new BinaryTree(6);
		  root.left.left.left.left.left.right = new BinaryTree(7);
		  root.right = new BinaryTree(8);
		  root.right.right = new BinaryTree(9);
		  root.right.right.right = new BinaryTree(10);
		  root.right.right.right.right = new BinaryTree(11);
		  root.right.right.right.right.right = new BinaryTree(12);
		  root.right.right.right.right.right.left = new BinaryTree(13);
		  const actual = program.nodeDepths(root);
		  chai.expect(actual).to.deep.equal(42);
		});
		it('Test Case #8', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  root.left.left = new BinaryTree(4);
		  root.left.left.left = new BinaryTree(8);
		  root.left.left.right = new BinaryTree(9);
		  root.left.right = new BinaryTree(5);
		  root.right = new BinaryTree(3);
		  root.right.left = new BinaryTree(6);
		  root.right.left.left = new BinaryTree(10);
		  root.right.left.left.right = new BinaryTree(11);
		  root.right.left.left.right.left = new BinaryTree(12);
		  root.right.left.left.right.left.left = new BinaryTree(14);
		  root.right.left.left.right.right = new BinaryTree(13);
		  root.right.left.left.right.right.left = new BinaryTree(15);
		  root.right.left.left.right.right.right = new BinaryTree(16);
		  root.right.right = new BinaryTree(7);
		  const actual = program.nodeDepths(root);
		  chai.expect(actual).to.deep.equal(51);
		});
		it('Test Case #9', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  root.left.left = new BinaryTree(3);
		  root.left.left.left = new BinaryTree(4);
		  root.left.left.left.left = new BinaryTree(5);
		  root.left.left.left.left.left = new BinaryTree(6);
		  root.left.left.left.left.left.left = new BinaryTree(7);
		  root.left.left.left.left.left.left.left = new BinaryTree(8);
		  root.left.left.left.left.left.left.left.left = new BinaryTree(9);
		  const actual = program.nodeDepths(root);
		  chai.expect(actual).to.deep.equal(36);
		});
		""",
		
		"Shift Linked List": """
		const program = require('./program');
		const chai = require('chai');
		class LinkedList {
		  constructor(value) {
			this.value = value;
			this.next = null;
		  }
		}
		function linkedListToArray(head) {
			const array = [];
			let current = head;
			while (current) {
				array.push(current.value);
				current = current.next;
			}
			return array;
		}
		it('Test Case #1', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(1);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(3);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  const result = program.shiftLinkedList(head, 2);
		  const array = linkedListToArray(result);
		  var expected = [4,5,0,1,2,3]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #2', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(1);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(3);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  const result = program.shiftLinkedList(head, 0);
		  const array = linkedListToArray(result);
		  var expected = [0,1,2,3,4,5]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #3', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(1);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(3);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  const result = program.shiftLinkedList(head, 1);
		  const array = linkedListToArray(result);
		  var expected = [5,0,1,2,3,4]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #4', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(1);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(3);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  const result = program.shiftLinkedList(head, 3);
		  const array = linkedListToArray(result);
		  var expected = [3,4,5,0,1,2]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #5', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(1);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(3);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  const result = program.shiftLinkedList(head, 4);
		  const array = linkedListToArray(result);
		  var expected = [2,3,4,5,0,1]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #6', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(1);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(3);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  const result = program.shiftLinkedList(head, 5);
		  const array = linkedListToArray(result);
		  var expected = [1,2,3,4,5,0]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #7', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(1);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(3);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  const result = program.shiftLinkedList(head, 6);
		  const array = linkedListToArray(result);
		  var expected = [0,1,2,3,4,5]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #8', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(1);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(3);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  const result = program.shiftLinkedList(head, 8);
		  const array = linkedListToArray(result);
		  var expected = [4,5,0,1,2,3]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #9', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(1);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(3);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  const result = program.shiftLinkedList(head, 14);
		  const array = linkedListToArray(result);
		  var expected = [4,5,0,1,2,3]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #10', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(1);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(3);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  const result = program.shiftLinkedList(head, 18);
		  const array = linkedListToArray(result);
		  var expected = [0,1,2,3,4,5]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #11', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(1);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(3);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  const result = program.shiftLinkedList(head, -1);
		  const array = linkedListToArray(result);
		  var expected = [1,2,3,4,5,0]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #12', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(1);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(3);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  const result = program.shiftLinkedList(head, -2);
		  const array = linkedListToArray(result);
		  var expected = [2,3,4,5,0,1]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #13', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(1);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(3);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  const result = program.shiftLinkedList(head, -3);
		  const array = linkedListToArray(result);
		  var expected = [3,4,5,0,1,2]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #14', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(1);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(3);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  const result = program.shiftLinkedList(head, -4);
		  const array = linkedListToArray(result);
		  var expected = [4,5,0,1,2,3]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #15', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(1);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(3);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  const result = program.shiftLinkedList(head, -5);
		  const array = linkedListToArray(result);
		  var expected = [5,0,1,2,3,4]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #16', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(1);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(3);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  const result = program.shiftLinkedList(head, -6);
		  const array = linkedListToArray(result);
		  var expected = [0,1,2,3,4,5]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #17', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(1);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(3);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  const result = program.shiftLinkedList(head, -8);
		  const array = linkedListToArray(result);
		  var expected = [2,3,4,5,0,1]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #18', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(1);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(3);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  const result = program.shiftLinkedList(head, -14);
		  const array = linkedListToArray(result);
		  var expected = [2,3,4,5,0,1]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #19', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(1);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(3);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  const result = program.shiftLinkedList(head, -18);
		  const array = linkedListToArray(result);
		  var expected = [0,1,2,3,4,5]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #20', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(1);
		  head.next.next = new LinkedList(4);
		  head.next.next.next = new LinkedList(3);
		  head.next.next.next.next = new LinkedList(5);
		  head.next.next.next.next.next = new LinkedList(2);
		  const result = program.shiftLinkedList(head, 2);
		  const array = linkedListToArray(result);
		  var expected = [5,2,0,1,4,3]
		  chai.expect(array).to.deep.equal(expected);
		});
		""",
		
		"Rearrange Linked List": """
		const program = require('./program');
		const chai = require('chai');
		class LinkedList {
		  constructor(value) {
			this.value = value;
			this.next = null;
		  }
		}
		function linkedListToArray(head) {
			const array = [];
			let current = head;
			while (current) {
				array.push(current.value);
				current = current.next;
			}
			return array;
		}
		it('Test Case #1', function () {
		  const head = new LinkedList(3);
		  head.next = new LinkedList(0);
		  head.next.next = new LinkedList(5);
		  head.next.next.next = new LinkedList(2);
		  head.next.next.next.next = new LinkedList(1);
		  head.next.next.next.next.next = new LinkedList(4);
		  const result = program.rearrangeLinkedList(head, 3);
		  const array = linkedListToArray(result);
		  var expected = [0,2,1,3,5,4]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #2', function () {
		  const head = new LinkedList(3);
		  head.next = new LinkedList(0);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(1);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  const result = program.rearrangeLinkedList(head, 4);
		  const array = linkedListToArray(result);
		  var expected = [3,0,2,1,4,5]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #3', function () {
		  const head = new LinkedList(3);
		  head.next = new LinkedList(0);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(1);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  const result = program.rearrangeLinkedList(head, 5);
		  const array = linkedListToArray(result);
		  var expected = [3,0,2,1,4,5]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #4', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(3);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(1);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  const result = program.rearrangeLinkedList(head, 0);
		  const array = linkedListToArray(result);
		  var expected = [0,3,2,1,4,5]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #5', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(3);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(1);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  head.next.next.next.next.next.next = new LinkedList(3);
		  head.next.next.next.next.next.next.next = new LinkedList(-1);
		  head.next.next.next.next.next.next.next.next = new LinkedList(-2);
		  head.next.next.next.next.next.next.next.next.next = new LinkedList(3);
		  head.next.next.next.next.next.next.next.next.next.next = new LinkedList(6);
		  head.next.next.next.next.next.next.next.next.next.next.next = new LinkedList(7);
		  head.next.next.next.next.next.next.next.next.next.next.next.next = new LinkedList(3);
		  head.next.next.next.next.next.next.next.next.next.next.next.next.next = new LinkedList(2);
		  head.next.next.next.next.next.next.next.next.next.next.next.next.next.next = new LinkedList(-9000);
		  const result = program.rearrangeLinkedList(head, -9000);
		  const array = linkedListToArray(result);
		  var expected = [-9000,0,3,2,1,4,5,3,-1,-2,3,6,7,3,2]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #6', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(3);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(1);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  head.next.next.next.next.next.next = new LinkedList(3);
		  head.next.next.next.next.next.next.next = new LinkedList(-1);
		  head.next.next.next.next.next.next.next.next = new LinkedList(-2);
		  head.next.next.next.next.next.next.next.next.next = new LinkedList(3);
		  head.next.next.next.next.next.next.next.next.next.next = new LinkedList(6);
		  head.next.next.next.next.next.next.next.next.next.next.next = new LinkedList(7);
		  head.next.next.next.next.next.next.next.next.next.next.next.next = new LinkedList(3);
		  head.next.next.next.next.next.next.next.next.next.next.next.next.next = new LinkedList(2);
		  head.next.next.next.next.next.next.next.next.next.next.next.next.next.next = new LinkedList(-9000);
		  const result = program.rearrangeLinkedList(head, 2);
		  const array = linkedListToArray(result);
		  var expected = [0,1,-1,-2,-9000,2,2,3,4,5,3,3,6,7,3]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #7', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(3);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(1);
		  head.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next = new LinkedList(5);
		  head.next.next.next.next.next.next = new LinkedList(3);
		  head.next.next.next.next.next.next.next = new LinkedList(-1);
		  head.next.next.next.next.next.next.next.next = new LinkedList(-2);
		  head.next.next.next.next.next.next.next.next.next = new LinkedList(3);
		  head.next.next.next.next.next.next.next.next.next.next = new LinkedList(6);
		  head.next.next.next.next.next.next.next.next.next.next.next = new LinkedList(7);
		  head.next.next.next.next.next.next.next.next.next.next.next.next = new LinkedList(3);
		  head.next.next.next.next.next.next.next.next.next.next.next.next.next = new LinkedList(2);
		  head.next.next.next.next.next.next.next.next.next.next.next.next.next.next = new LinkedList(-9000);
		  const result = program.rearrangeLinkedList(head, 3);
		  const array = linkedListToArray(result);
		  var expected = [0,2,1,-1,-2,2,-9000,3,3,3,3,4,5,6,7]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #8', function () {
		  const head = new LinkedList(0);
		  head.next = new LinkedList(1);
		  head.next.next = new LinkedList(2);
		  head.next.next.next = new LinkedList(3);
		  head.next.next.next.next = new LinkedList(3);
		  head.next.next.next.next.next = new LinkedList(3);
		  head.next.next.next.next.next.next = new LinkedList(3);
		  head.next.next.next.next.next.next.next = new LinkedList(4);
		  head.next.next.next.next.next.next.next.next = new LinkedList(5);
		  head.next.next.next.next.next.next.next.next.next = new LinkedList(6);
		  head.next.next.next.next.next.next.next.next.next.next = new LinkedList(7);
		  head.next.next.next.next.next.next.next.next.next.next.next = new LinkedList(8);
		  head.next.next.next.next.next.next.next.next.next.next.next.next = new LinkedList(9);
		  const result = program.rearrangeLinkedList(head, 3);
		  const array = linkedListToArray(result);
		  var expected = [0,1,2,3,3,3,3,4,5,6,7,8,9]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #9', function () {
		  const head = new LinkedList(3);
		  head.next = new LinkedList(0);
		  head.next.next = new LinkedList(5);
		  head.next.next.next = new LinkedList(2);
		  head.next.next.next.next = new LinkedList(1);
		  head.next.next.next.next.next = new LinkedList(4);
		  const result = program.rearrangeLinkedList(head, -1);
		  const array = linkedListToArray(result);
		  var expected = [3,0,5,2,1,4]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #10', function () {
		  const head = new LinkedList(3);
		  head.next = new LinkedList(0);
		  head.next.next = new LinkedList(5);
		  head.next.next.next = new LinkedList(2);
		  head.next.next.next.next = new LinkedList(1);
		  head.next.next.next.next.next = new LinkedList(4);
		  const result = program.rearrangeLinkedList(head, 6);
		  const array = linkedListToArray(result);
		  var expected = [3,0,5,2,1,4]
		  chai.expect(array).to.deep.equal(expected);
		});
		it('Test Case #11', function () {
		  const head = new LinkedList(6);
		  head.next = new LinkedList(0);
		  head.next.next = new LinkedList(5);
		  head.next.next.next = new LinkedList(2);
		  head.next.next.next.next = new LinkedList(1);
		  head.next.next.next.next.next = new LinkedList(4);
		  const result = program.rearrangeLinkedList(head, 3);
		  const array = linkedListToArray(result);
		  var expected = [0,2,1,6,5,4]
		  chai.expect(array).to.deep.equal(expected);
		});
		""",
		
		"Shorten Path": """
		const program = require('./program');
		const chai = require('chai');
		it('Test Case #1', function () {
		  chai.expect(program.shortenPath("/foo/../test/../test/../foo//bar/./baz")).to.deep.equal("/foo/bar/baz");
		});
		it('Test Case #2', function () {
		  chai.expect(program.shortenPath("/foo/bar/baz")).to.deep.equal("/foo/bar/baz");
		});
		it('Test Case #3', function () {
		  chai.expect(program.shortenPath("foo/bar/baz")).to.deep.equal("foo/bar/baz");
		});
		it('Test Case #4', function () {
		  chai.expect(program.shortenPath("/../../foo/bar/baz")).to.deep.equal("/foo/bar/baz");
		});
		it('Test Case #5', function () {
		  chai.expect(program.shortenPath("../../foo/bar/baz")).to.deep.equal("../../foo/bar/baz");
		});
		it('Test Case #6', function () {
		  chai.expect(program.shortenPath("/../../foo/../../bar/baz")).to.deep.equal("/bar/baz");
		});
		it('Test Case #7', function () {
		  chai.expect(program.shortenPath("../../foo/../../bar/baz")).to.deep.equal("../../../bar/baz");
		});
		it('Test Case #8', function () {
		  chai.expect(program.shortenPath("/foo/./././bar/./baz///////////test/../../../kappa")).to.deep.equal("/foo/kappa");
		});
		it('Test Case #9', function () {
		  chai.expect(program.shortenPath("../../../this////one/./../../is/../../going/../../to/be/./././../../../just/eight/double/dots/../../../../../..")).to.deep.equal("../../../../../../../..");
		});
		it('Test Case #10', function () {
		  chai.expect(program.shortenPath("/../../../this////one/./../../is/../../going/../../to/be/./././../../../just/a/forward/slash/../../../../../..")).to.deep.equal("/");
		});
		it('Test Case #11', function () {
		  chai.expect(program.shortenPath("../../../this////one/./../../is/../../going/../../to/be/./././../../../just/eight/double/dots/../../../../../../foo")).to.deep.equal("../../../../../../../../foo");
		});
		it('Test Case #12', function () {
		  chai.expect(program.shortenPath("/../../../this////one/./../../is/../../going/../../to/be/./././../../../just/a/forward/slash/../../../../../../foo")).to.deep.equal("/foo");
		});
		it('Test Case #13', function () {
		  chai.expect(program.shortenPath("foo/bar/..")).to.deep.equal("foo");
		});
		it('Test Case #14', function () {
		  chai.expect(program.shortenPath("./foo/bar")).to.deep.equal("foo/bar");
		});
		it('Test Case #15', function () {
		  chai.expect(program.shortenPath("foo/../..")).to.deep.equal("..");
		});
		it('Test Case #16', function () {
		  chai.expect(program.shortenPath("/")).to.deep.equal("/");
		});
		""",
		
		"Validate Subsequence": """
		const program = require('./program');
		const chai = require('chai');
		it('Test Case #1', function () {
		  const array = [5,1,22,25,6,-1,8,10];
		  const sequence = [1,6,-1,10];
		  chai.expect(program.isValidSubsequence(array, sequence)).to.deep.equal(true);
		});
		it('Test Case #2', function () {
		  const array = [5,1,22,25,6,-1,8,10];
		  const sequence = [5,1,22,25,6,-1,8,10];
		  chai.expect(program.isValidSubsequence(array, sequence)).to.deep.equal(true);
		});
		it('Test Case #3', function () {
		  const array = [5,1,22,25,6,-1,8,10];
		  const sequence = [5,1,22,6,-1,8,10];
		  chai.expect(program.isValidSubsequence(array, sequence)).to.deep.equal(true);
		});
		it('Test Case #4', function () {
		  const array = [5,1,22,25,6,-1,8,10];
		  const sequence = [22,25,6];
		  chai.expect(program.isValidSubsequence(array, sequence)).to.deep.equal(true);
		});
		it('Test Case #5', function () {
		  const array = [5,1,22,25,6,-1,8,10];
		  const sequence = [1,6,10];
		  chai.expect(program.isValidSubsequence(array, sequence)).to.deep.equal(true);
		});
		it('Test Case #6', function () {
		  const array = [5,1,22,25,6,-1,8,10];
		  const sequence = [5,1,22,10];
		  chai.expect(program.isValidSubsequence(array, sequence)).to.deep.equal(true);
		});
		it('Test Case #7', function () {
		  const array = [5,1,22,25,6,-1,8,10];
		  const sequence = [5,-1,8,10];
		  chai.expect(program.isValidSubsequence(array, sequence)).to.deep.equal(true);
		});
		it('Test Case #8', function () {
		  const array = [5,1,22,25,6,-1,8,10];
		  const sequence = [25];
		  chai.expect(program.isValidSubsequence(array, sequence)).to.deep.equal(true);
		});
		it('Test Case #9', function () {
		  const array = [1,1,1,1,1];
		  const sequence = [1,1,1];
		  chai.expect(program.isValidSubsequence(array, sequence)).to.deep.equal(true);
		});
		it('Test Case #10', function () {
		  const array = [5,1,22,25,6,-1,8,10];
		  const sequence = [5,1,22,25,6,-1,8,10,12];
		  chai.expect(program.isValidSubsequence(array, sequence)).to.deep.equal(false);
		});
		it('Test Case #11', function () {
		  const array = [5,1,22,25,6,-1,8,10];
		  const sequence = [4,5,1,22,25,6,-1,8,10];
		  chai.expect(program.isValidSubsequence(array, sequence)).to.deep.equal(false);
		});
		it('Test Case #12', function () {
		  const array = [5,1,22,25,6,-1,8,10];
		  const sequence = [5,1,22,23,6,-1,8,10];
		  chai.expect(program.isValidSubsequence(array, sequence)).to.deep.equal(false);
		});
		it('Test Case #13', function () {
		  const array = [5,1,22,25,6,-1,8,10];
		  const sequence = [5,1,22,22,25,6,-1,8,10];
		  chai.expect(program.isValidSubsequence(array, sequence)).to.deep.equal(false);
		});
		it('Test Case #14', function () {
		  const array = [5,1,22,25,6,-1,8,10];
		  const sequence = [5,1,22,22,6,-1,8,10];
		  chai.expect(program.isValidSubsequence(array, sequence)).to.deep.equal(false);
		});
		it('Test Case #15', function () {
		  const array = [5,1,22,25,6,-1,8,10];
		  const sequence = [1,6,-1,-1];
		  chai.expect(program.isValidSubsequence(array, sequence)).to.deep.equal(false);
		});
		it('Test Case #16', function () {
		  const array = [5,1,22,25,6,-1,8,10];
		  const sequence = [1,6,-1,-1,10];
		  chai.expect(program.isValidSubsequence(array, sequence)).to.deep.equal(false);
		});
		it('Test Case #17', function () {
		  const array = [5,1,22,25,6,-1,8,10];
		  const sequence = [1,6,-1,-2];
		  chai.expect(program.isValidSubsequence(array, sequence)).to.deep.equal(false);
		});
		it('Test Case #18', function () {
		  const array = [5,1,22,25,6,-1,8,10];
		  const sequence = [26];
		  chai.expect(program.isValidSubsequence(array, sequence)).to.deep.equal(false);
		});
		it('Test Case #19', function () {
		  const array = [5,1,22,25,6,-1,8,10];
		  const sequence = [5,1,25,22,6,-1,8,10];
		  chai.expect(program.isValidSubsequence(array, sequence)).to.deep.equal(false);
		});
		it('Test Case #20', function () {
		  const array = [5,1,22,25,6,-1,8,10];
		  const sequence = [5,26,22,8];
		  chai.expect(program.isValidSubsequence(array, sequence)).to.deep.equal(false);
		});
		it('Test Case #21', function () {
		  const array = [1,1,6,1];
		  const sequence = [1,1,1,6];
		  chai.expect(program.isValidSubsequence(array, sequence)).to.deep.equal(false);
		});
		it('Test Case #22', function () {
		  const array = [5,1,22,25,6,-1,8,10];
		  const sequence = [1,6,-1,10,11,11,11,11];
		  chai.expect(program.isValidSubsequence(array, sequence)).to.deep.equal(false);
		});
		it('Test Case #23', function () {
		  const array = [5,1,22,25,6,-1,8,10];
		  const sequence = [5,1,22,25,6,-1,8,10,10];
		  chai.expect(program.isValidSubsequence(array, sequence)).to.deep.equal(false);
		});
		""",
		
		"Merge Sorted Arrays": """
		const program = require('./program');
		const chai = require('chai');
		it('Test Case #1', function () {
		  chai.expect(program.mergeSortedArrays([[1,5,9,21],[-1,0],[-124,81,121],[3,6,12,20,150]])).to.deep.equal([-124,-1,0,1,3,5,6,9,12,20,21,81,121,150]);
		});
		it('Test Case #2', function () {
		  chai.expect(program.mergeSortedArrays([[-92,-78,-68,43,46,46,79,79],[-66,-49,-26,-16,21,28,33,50],[-40,-8,12,20,36,38,81],[-76,-74,-62,-46,-23,33,42,48,55,94]])).to.deep.equal([-92,-78,-76,-74,-68,-66,-62,-49,-46,-40,-26,-23,-16,-8,12,20,21,28,33,33,36,38,42,43,46,46,48,50,55,79,79,81,94]);
		});
		it('Test Case #3', function () {
		  chai.expect(program.mergeSortedArrays([[-95,-74,1],[-28,28,95],[-89,-78,-67,-66,-25,-22,2,38],[-86,-35,-25,-13,41],[-85,-77,-21,72],[-55,4,84,98],[-75,-73,22]])).to.deep.equal([-95,-89,-86,-85,-78,-77,-75,-74,-73,-67,-66,-55,-35,-28,-25,-25,-22,-21,-13,1,2,4,22,28,38,41,72,84,95,98]);
		});
		it('Test Case #4', function () {
		  chai.expect(program.mergeSortedArrays([[-79,-43,-15,89],[-48,13,20],[-33,-19,-8,12,40,44,50,52,91,95],[-100,-43,-8,17],[-15,81]])).to.deep.equal([-100,-79,-48,-43,-43,-33,-19,-15,-15,-8,-8,12,13,17,20,40,44,50,52,81,89,91,95]);
		});
		it('Test Case #5', function () {
		  chai.expect(program.mergeSortedArrays([[-88,-56,-43,-41,-13,-8,82],[-38,53],[-75,-48,-42,-27,20,35,55],[-55,-50,-48,-45,62,69,77],[-90,-27,-22,-19,-6,-3,4,6,91],[-86,-67,-66,2,8,8,39,74],[-62,34,40,42,47,48,55,56,68,87]])).to.deep.equal([-90,-88,-86,-75,-67,-66,-62,-56,-55,-50,-48,-48,-45,-43,-42,-41,-38,-27,-27,-22,-19,-13,-8,-6,-3,2,4,6,8,8,20,34,35,39,40,42,47,48,53,55,55,56,62,68,69,74,77,82,87,91]);
		});
		it('Test Case #6', function () {
		  chai.expect(program.mergeSortedArrays([[-93,-83,-43,-32,-32,-15,-14,12,78,80],[-83],[-82,-51,-29,40,60,76,80],[50],[-33,-16],[-100],[-33,-11,23,29,29,43],[0,70],[-57,-43,-41,-18,-5,74]])).to.deep.equal([-100,-93,-83,-83,-82,-57,-51,-43,-43,-41,-33,-33,-32,-32,-29,-18,-16,-15,-14,-11,-5,0,12,23,29,29,40,43,50,60,70,74,76,78,80,80]);
		});
		it('Test Case #7', function () {
		  chai.expect(program.mergeSortedArrays([[98],[-87,-79,-56,-33,-20,-10,-5,19,49,86],[-73,-49],[-98,-63,-47,-4,21],[-56,-43,-24,8,34,80,83],[-83,-65,-61,-30,-26,-16,16,19],[-91,-42,-21,91],[-73,-62,-56,-30,11,67],[-91,-90,-40,32,94]])).to.deep.equal([-98,-91,-91,-90,-87,-83,-79,-73,-73,-65,-63,-62,-61,-56,-56,-56,-49,-47,-43,-42,-40,-33,-30,-30,-26,-24,-21,-20,-16,-10,-5,-4,8,11,16,19,19,21,32,34,49,67,80,83,86,91,94,98]);
		});
		it('Test Case #8', function () {
		  chai.expect(program.mergeSortedArrays([[-81,36,57,59],[-65,-58,-47,-39,29,53,66,75,88,92],[-67,-54,-40,-25,9,17,55,75,94],[-35,-3,24,82],[-86,32,95]])).to.deep.equal([-86,-81,-67,-65,-58,-54,-47,-40,-39,-35,-25,-3,9,17,24,29,32,36,53,55,57,59,66,75,75,82,88,92,94,95]);
		});
		it('Test Case #9', function () {
		  chai.expect(program.mergeSortedArrays([[-93,-83,-78,-75,-40,-32,48],[-90,-75,-57,7,11,21,53,84,89],[-50,-40,-20,71,96],[-49,13,18,61,97],[42,96]])).to.deep.equal([-93,-90,-83,-78,-75,-75,-57,-50,-49,-40,-40,-32,-20,7,11,13,18,21,42,48,53,61,71,84,89,96,96,97]);
		});
		it('Test Case #10', function () {
		  chai.expect(program.mergeSortedArrays([[-63,-55,-9,37,86,97],[-62,-48,-37,-16,11,33,80,97],[-51,5,34],[-24,-24,-19,32,46,97],[-98,-56,-12,-2,-1,11,47,79],[-59,64,93,96],[-96,-51,-21,-18,29,57,87,90,92],[-89,-85,-55,-12,27],[-96,-96,-95,-95,-71,-45,-28,8,19,100]])).to.deep.equal([-98,-96,-96,-96,-95,-95,-89,-85,-71,-63,-62,-59,-56,-55,-55,-51,-51,-48,-45,-37,-28,-24,-24,-21,-19,-18,-16,-12,-12,-9,-2,-1,5,8,11,11,19,27,29,32,33,34,37,46,47,57,64,79,80,86,87,90,92,93,96,97,97,97,100]);
		});
		it('Test Case #11', function () {
		  chai.expect(program.mergeSortedArrays([[49,72],[-95,-49,-18,-16,1,16,36,40,75,92],[-77,11,65,91]])).to.deep.equal([-95,-77,-49,-18,-16,1,11,16,36,40,49,65,72,75,91,92]);
		});
		it('Test Case #12', function () {
		  chai.expect(program.mergeSortedArrays([[-94,-93,-25,-2,67,85],[-83,-74,64],[-83,10,46,64],[-94,-54,-40,9,22,49]])).to.deep.equal([-94,-94,-93,-83,-83,-74,-54,-40,-25,-2,9,10,22,46,49,64,64,67,85]);
		});
		it('Test Case #13', function () {
		  chai.expect(program.mergeSortedArrays([[-87,-67,-56,-15,67],[-98,-90,-85,-3,5,43,44],[-97,-78,-73,-65,-17,27,66,77,78,92],[-99,-62,11,15,50]])).to.deep.equal([-99,-98,-97,-90,-87,-85,-78,-73,-67,-65,-62,-56,-17,-15,-3,5,11,15,27,43,44,50,66,67,77,78,92]);
		});
		it('Test Case #14', function () {
		  chai.expect(program.mergeSortedArrays([[-79,-77,-48,-39,-27,10,39,61,83,99],[-93,10],[-98,-90,-44,-33,-5,40,69,90,96],[-93],[-32,9,14,20,85]])).to.deep.equal([-98,-93,-93,-90,-79,-77,-48,-44,-39,-33,-32,-27,-5,9,10,10,14,20,39,40,61,69,83,85,90,96,99]);
		});
		it('Test Case #15', function () {
		  chai.expect(program.mergeSortedArrays([[14],[-88,-16,26,38,51,62,84,88]])).to.deep.equal([-88,-16,14,26,38,51,62,84,88]);
		});
		it('Test Case #16', function () {
		  chai.expect(program.mergeSortedArrays([[-62,-54,-54,31,34,51],[-41],[33,34],[-98,68,83],[-25,-14]])).to.deep.equal([-98,-62,-54,-54,-41,-25,-14,31,33,34,34,51,68,83]);
		});
		it('Test Case #17', function () {
		  chai.expect(program.mergeSortedArrays([[-53,-16,-13,-11,-6,21,26,35],[-99,-93,-62,-47,-16,4,55,59,64,76],[-96,-41,-8],[-39,-28,-4],[-95,-48,-45,-25,63,64,98],[-38,-32,-7,82],[-42,25,49,79,86],[-88,-65,7,8,44]])).to.deep.equal([-99,-96,-95,-93,-88,-65,-62,-53,-48,-47,-45,-42,-41,-39,-38,-32,-28,-25,-16,-16,-13,-11,-8,-7,-6,-4,4,7,8,21,25,26,35,44,49,55,59,63,64,64,76,79,82,86,98]);
		});
		it('Test Case #18', function () {
		  chai.expect(program.mergeSortedArrays([[-33,57,74],[-76,-72,-46,-21,-16,-10,16,21,47,67],[-59,-55,-47,-46,-35,38],[-62,-25,3,30,46,71],[-91,-37,-26,-12,-8,2,9,46,56,93],[-58,82,97]])).to.deep.equal([-91,-76,-72,-62,-59,-58,-55,-47,-46,-46,-37,-35,-33,-26,-25,-21,-16,-12,-10,-8,2,3,9,16,21,30,38,46,46,47,56,57,67,71,74,82,93,97]);
		});
		it('Test Case #19', function () {
		  chai.expect(program.mergeSortedArrays([[-64,-51,-5,1,6,12,27,32,62,88],[-66,-65,-60,17,22],[-57,-7,13,70,79],[-88,-86,-73,-59,-36,-12,11,48,58,99],[-71,-28],[21,38],[-55,-44,-27],[-96,-93,-5,13],[-19,-11,27,36,43,79,87],[-72,-53,-10,1,27,77,88]])).to.deep.equal([-96,-93,-88,-86,-73,-72,-71,-66,-65,-64,-60,-59,-57,-55,-53,-51,-44,-36,-28,-27,-19,-12,-11,-10,-7,-5,-5,1,1,6,11,12,13,13,17,21,22,27,27,27,32,36,38,43,48,58,62,70,77,79,79,87,88,88,99]);
		});
		it('Test Case #20', function () {
		  chai.expect(program.mergeSortedArrays([[-19,33,34],[-94,-53,-10,-3,44,73],[27,42,70,86],[-28,91],[-53,-27,31,77,96,99]])).to.deep.equal([-94,-53,-53,-28,-27,-19,-10,-3,27,31,33,34,42,44,70,73,77,86,91,96,99]);
		});
		""",
		"Right Smaller Than": """
		const program = require('./program');
		const chai = require('chai');
		
		it('Test Case #1', function () {
		  chai.expect(program.rightSmallerThan([8,5,11,-1,3,4,2])).to.deep.equal([5,4,4,0,1,1,0]);
		});
		it('Test Case #2', function () {
		  chai.expect(program.rightSmallerThan([])).to.deep.equal([]);
		});
		it('Test Case #3', function () {
		  chai.expect(program.rightSmallerThan([1])).to.deep.equal([0]);
		});
		it('Test Case #4', function () {
		  chai.expect(program.rightSmallerThan([0,1,1,2,3,5,8,13])).to.deep.equal([0,0,0,0,0,0,0,0]);
		});
		it('Test Case #5', function () {
		  chai.expect(program.rightSmallerThan([13,8,5,3,2,1,1,0])).to.deep.equal([7,6,5,4,3,1,1,0]);
		});
		it('Test Case #6', function () {
		  chai.expect(program.rightSmallerThan([8,5,2,9,5,6,3])).to.deep.equal([5,2,0,3,1,1,0]);
		});
		it('Test Case #7', function () {
		  chai.expect(program.rightSmallerThan([991,-731,-882,100,280,-43,432,771,-581,180,-382,-998,847,80,-220,680,769,-75,-817,366,956,749,471,228,-435,-269,652,-331,-387,-657,-255,382,-216,-6,-163,-681,980,913,-169,972,-523,354,747,805,382,-827,-796,372,753,519,906])).to.deep.equal([50,5,1,22,24,19,28,36,6,20,9,0,33,17,11,25,28,14,1,16,28,23,19,14,5,7,17,6,5,3,4,10,4,6,5,2,14,12,3,11,2,2,5,6,3,0,0,0,1,0,0]);
		});
		it('Test Case #8', function () {
		  chai.expect(program.rightSmallerThan([384,-67,120,759,697,232,-7,-557,-772,-987,687,397,-763,-86,-491,947,921,421,825,-679,946,-562,-626,-898,204,776,-343,393,51,-796,-425,31,165,975,-720,878,-785,-367,-609,662,-79,-112,-313,-94,187,260,43,85,-746,612,67,-389,508,777,624,993,-581,34,444,-544,243,-995,432,-755,-978,515,-68,-559,489,732,-19,-489,737,924])).to.deep.equal([47,31,39,60,57,42,32,17,6,1,51,41,5,24,15,56,53,38,50,8,51,11,8,2,30,43,15,31,24,2,11,19,23,39,5,36,2,10,4,29,12,10,9,9,15,16,12,13,3,18,11,7,14,18,15,18,3,8,10,4,7,0,6,1,0,5,2,0,2,2,1,0,0,0]);
		});
		it('Test Case #9', function () {
		  chai.expect(program.rightSmallerThan([-823,164,48,-987,323,399,-293,183,-908,-376,14,980,965,842,422,829,59,724,-415,-733,356,-855,-155,52,328,-544,-371,-160,-942,-51,700,-363,-353,-359,238,892,-730,-575,892,490,490,995,572,888,-935,919,-191,646,-120,125,-817,341,-575,372,-874,243,610,-36,-685,-337,-13,295,800,-950,-949,-257,631,-542,201,-796,157,950,540,-846,-265,746,355,-578,-441,-254,-941,-738,-469,-167,-420,-126,-410,59])).to.deep.equal([10,52,46,0,55,60,31,49,5,24,41,75,74,68,55,66,42,62,22,11,50,6,32,37,44,15,20,29,2,30,49,19,20,19,33,48,9,11,46,36,36,46,37,42,3,41,20,37,22,25,5,28,9,28,3,24,27,19,6,12,17,20,24,0,0,11,19,5,15,2,13,16,14,1,7,12,11,2,3,5,0,0,0,2,0,1,0,0]);
		});
		""",
		
		"Max Path Sum In Binary Tree": """
		const program = require('./program');
		const chai = require('chai');
		class BinaryTree {
		  constructor(value) {
			this.value = value;
			this.left = null;
			this.right = null;
		  }
		}
		it('Test Case #1', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  root.left.left = new BinaryTree(4);
		  root.left.right = new BinaryTree(5);
		  root.right = new BinaryTree(3);
		  root.right.left = new BinaryTree(6);
		  root.right.right = new BinaryTree(7);
		  chai.expect(program.maxPathSum(root)).to.deep.equal(18);
		});
		it('Test Case #2', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  root.right = new BinaryTree(3);
		  chai.expect(program.maxPathSum(root)).to.deep.equal(6);
		});
		it('Test Case #3', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2);
		  root.right = new BinaryTree(-1);
		  chai.expect(program.maxPathSum(root)).to.deep.equal(3);
		});
		it('Test Case #4', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(-5);
		  root.left.left = new BinaryTree(6);
		  root.right = new BinaryTree(3);
		  chai.expect(program.maxPathSum(root)).to.deep.equal(6);
		});
		it('Test Case #5', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(-10);
		  root.left.left = new BinaryTree(30);
		  root.left.left.left = new BinaryTree(5);
		  root.left.left.right = new BinaryTree(1);
		  root.left.right = new BinaryTree(45);
		  root.left.right.left = new BinaryTree(3);
		  root.left.right.right = new BinaryTree(-3);
		  root.right = new BinaryTree(-5);
		  root.right.left = new BinaryTree(-20);
		  root.right.left.left = new BinaryTree(100);
		  root.right.left.right = new BinaryTree(2);
		  root.right.right = new BinaryTree(-21);
		  root.right.right.left = new BinaryTree(100);
		  root.right.right.right = new BinaryTree(1);
		  chai.expect(program.maxPathSum(root)).to.deep.equal(154);
		});
		it('Test Case #6', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(-10);
		  root.left.left = new BinaryTree(30);
		  root.left.left.left = new BinaryTree(5);
		  root.left.left.left.left = new BinaryTree(100);
		  root.left.left.right = new BinaryTree(1);
		  root.left.right = new BinaryTree(45);
		  root.left.right.left = new BinaryTree(3);
		  root.left.right.right = new BinaryTree(-3);
		  root.right = new BinaryTree(-5);
		  root.right.left = new BinaryTree(-20);
		  root.right.left.left = new BinaryTree(100);
		  root.right.left.right = new BinaryTree(2);
		  root.right.right = new BinaryTree(-21);
		  root.right.right.left = new BinaryTree(100);
		  root.right.right.right = new BinaryTree(1);
		  chai.expect(program.maxPathSum(root)).to.deep.equal(201);
		});
		it('Test Case #7', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(-10);
		  root.left.left = new BinaryTree(30);
		  root.left.left.left = new BinaryTree(5);
		  root.left.left.left.left = new BinaryTree(100);
		  root.left.left.right = new BinaryTree(1);
		  root.left.right = new BinaryTree(75);
		  root.left.right.left = new BinaryTree(3);
		  root.left.right.right = new BinaryTree(-3);
		  root.right = new BinaryTree(-5);
		  root.right.left = new BinaryTree(-20);
		  root.right.left.left = new BinaryTree(100);
		  root.right.left.right = new BinaryTree(2);
		  root.right.right = new BinaryTree(-21);
		  root.right.right.left = new BinaryTree(100);
		  root.right.right.right = new BinaryTree(1);
		  chai.expect(program.maxPathSum(root)).to.deep.equal(203);
		});
		it('Test Case #8', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(-150);
		  root.left.left = new BinaryTree(30);
		  root.left.left.left = new BinaryTree(5);
		  root.left.left.left.left = new BinaryTree(100);
		  root.left.left.left.right = new BinaryTree(100);
		  root.left.left.right = new BinaryTree(1);
		  root.left.left.right.left = new BinaryTree(5);
		  root.left.left.right.right = new BinaryTree(10);
		  root.left.right = new BinaryTree(75);
		  root.left.right.left = new BinaryTree(3);
		  root.left.right.left.left = new BinaryTree(150);
		  root.left.right.left.right = new BinaryTree(-8);
		  root.left.right.right = new BinaryTree(-3);
		  root.right = new BinaryTree(-5);
		  root.right.left = new BinaryTree(-20);
		  root.right.left.left = new BinaryTree(100);
		  root.right.left.right = new BinaryTree(2);
		  root.right.right = new BinaryTree(-21);
		  root.right.right.left = new BinaryTree(100);
		  root.right.right.right = new BinaryTree(1);
		  chai.expect(program.maxPathSum(root)).to.deep.equal(228);
		});
		it('Test Case #9', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(-150);
		  root.left.left = new BinaryTree(30);
		  root.left.left.left = new BinaryTree(5);
		  root.left.left.left.left = new BinaryTree(100);
		  root.left.left.left.right = new BinaryTree(100);
		  root.left.left.right = new BinaryTree(1);
		  root.left.left.right.left = new BinaryTree(5);
		  root.left.left.right.right = new BinaryTree(10);
		  root.left.right = new BinaryTree(75);
		  root.left.right.left = new BinaryTree(3);
		  root.left.right.left.left = new BinaryTree(150);
		  root.left.right.left.right = new BinaryTree(151);
		  root.left.right.right = new BinaryTree(-3);
		  root.right = new BinaryTree(-5);
		  root.right.left = new BinaryTree(-20);
		  root.right.left.left = new BinaryTree(100);
		  root.right.left.right = new BinaryTree(2);
		  root.right.right = new BinaryTree(-21);
		  root.right.right.left = new BinaryTree(100);
		  root.right.right.right = new BinaryTree(1);
		  chai.expect(program.maxPathSum(root)).to.deep.equal(304);
		});
		it('Test Case #10', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(-5);
		  root.left.left = new BinaryTree(0);
		  root.left.left.left = new BinaryTree(-3);
		  root.left.left.left.left = new BinaryTree(0);
		  root.left.left.left.right = new BinaryTree(1);
		  root.left.left.right = new BinaryTree(3);
		  root.left.left.right.left = new BinaryTree(1);
		  root.left.left.right.right = new BinaryTree(-1);
		  root.left.right = new BinaryTree(2);
		  root.left.right.left = new BinaryTree(1);
		  root.left.right.left.left = new BinaryTree(-1);
		  root.left.right.left.right = new BinaryTree(-6);
		  root.left.right.right = new BinaryTree(1);
		  root.left.right.right.left = new BinaryTree(-1);
		  root.left.right.right.right = new BinaryTree(-100);
		  root.right = new BinaryTree(-3);
		  root.right.left = new BinaryTree(2);
		  root.right.left.left = new BinaryTree(0);
		  root.right.left.left.left = new BinaryTree(-9);
		  root.right.left.left.right = new BinaryTree(-91);
		  root.right.left.right = new BinaryTree(5);
		  root.right.left.right.left = new BinaryTree(2);
		  root.right.left.right.right = new BinaryTree(1);
		  root.right.right = new BinaryTree(1);
		  root.right.right.left = new BinaryTree(1);
		  root.right.right.left.left = new BinaryTree(0);
		  root.right.right.left.right = new BinaryTree(1);
		  root.right.right.right = new BinaryTree(1);
		  root.right.right.right.left = new BinaryTree(-5);
		  root.right.right.right.right = new BinaryTree(0);
		  chai.expect(program.maxPathSum(root)).to.deep.equal(9);
		});
		it('Test Case #11', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(-5);
		  root.left.left = new BinaryTree(0);
		  root.left.left.left = new BinaryTree(-3);
		  root.left.left.left.left = new BinaryTree(0);
		  root.left.left.left.right = new BinaryTree(1);
		  root.left.left.right = new BinaryTree(-4);
		  root.left.left.right.left = new BinaryTree(10);
		  root.left.left.right.right = new BinaryTree(-1);
		  root.left.right = new BinaryTree(2);
		  root.left.right.left = new BinaryTree(1);
		  root.left.right.left.left = new BinaryTree(-1);
		  root.left.right.left.right = new BinaryTree(-6);
		  root.left.right.right = new BinaryTree(1);
		  root.left.right.right.left = new BinaryTree(-1);
		  root.left.right.right.right = new BinaryTree(-100);
		  root.right = new BinaryTree(-3);
		  root.right.left = new BinaryTree(2);
		  root.right.left.left = new BinaryTree(0);
		  root.right.left.left.left = new BinaryTree(-9);
		  root.right.left.left.right = new BinaryTree(-91);
		  root.right.left.right = new BinaryTree(5);
		  root.right.left.right.left = new BinaryTree(2);
		  root.right.left.right.right = new BinaryTree(1);
		  root.right.right = new BinaryTree(1);
		  root.right.right.left = new BinaryTree(1);
		  root.right.right.left.left = new BinaryTree(0);
		  root.right.right.left.right = new BinaryTree(1);
		  root.right.right.right = new BinaryTree(1);
		  root.right.right.right.left = new BinaryTree(-5);
		  root.right.right.right.right = new BinaryTree(0);
		  chai.expect(program.maxPathSum(root)).to.deep.equal(10);
		});
		it('Test Case #12', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(-5);
		  root.left.left = new BinaryTree(0);
		  root.left.left.left = new BinaryTree(-3);
		  root.left.left.left.left = new BinaryTree(0);
		  root.left.left.left.left.left = new BinaryTree(3);
		  root.left.left.left.left.right = new BinaryTree(1);
		  root.left.left.left.right = new BinaryTree(1);
		  root.left.left.left.right.left = new BinaryTree(2);
		  root.left.left.left.right.right = new BinaryTree(2);
		  root.left.left.right = new BinaryTree(-4);
		  root.left.left.right.left = new BinaryTree(3);
		  root.left.left.right.left.left = new BinaryTree(7);
		  root.left.left.right.left.right = new BinaryTree(-5);
		  root.left.left.right.right = new BinaryTree(-1);
		  root.left.right = new BinaryTree(2);
		  root.left.right.left = new BinaryTree(1);
		  root.left.right.left.left = new BinaryTree(-1);
		  root.left.right.left.right = new BinaryTree(-6);
		  root.left.right.right = new BinaryTree(1);
		  root.left.right.right.left = new BinaryTree(-1);
		  root.left.right.right.right = new BinaryTree(-100);
		  root.right = new BinaryTree(-3);
		  root.right.left = new BinaryTree(2);
		  root.right.left.left = new BinaryTree(0);
		  root.right.left.left.left = new BinaryTree(-9);
		  root.right.left.left.right = new BinaryTree(-91);
		  root.right.left.right = new BinaryTree(5);
		  root.right.left.right.left = new BinaryTree(2);
		  root.right.left.right.right = new BinaryTree(1);
		  root.right.right = new BinaryTree(1);
		  root.right.right.left = new BinaryTree(1);
		  root.right.right.left.left = new BinaryTree(0);
		  root.right.right.left.right = new BinaryTree(1);
		  root.right.right.right = new BinaryTree(1);
		  root.right.right.right.left = new BinaryTree(-5);
		  root.right.right.right.right = new BinaryTree(0);
		  chai.expect(program.maxPathSum(root)).to.deep.equal(10);
		});
		it('Test Case #13', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(-5);
		  root.left.left = new BinaryTree(0);
		  root.left.left.left = new BinaryTree(-3);
		  root.left.left.left.left = new BinaryTree(0);
		  root.left.left.left.right = new BinaryTree(1);
		  root.left.left.right = new BinaryTree(3);
		  root.left.left.right.left = new BinaryTree(1);
		  root.left.left.right.right = new BinaryTree(-1);
		  root.left.right = new BinaryTree(2);
		  root.left.right.left = new BinaryTree(1);
		  root.left.right.left.left = new BinaryTree(-1);
		  root.left.right.left.right = new BinaryTree(-6);
		  root.left.right.right = new BinaryTree(1);
		  root.left.right.right.left = new BinaryTree(-1);
		  root.left.right.right.right = new BinaryTree(-100);
		  root.right = new BinaryTree(-3);
		  root.right.left = new BinaryTree(2);
		  root.right.left.left = new BinaryTree(0);
		  root.right.left.left.left = new BinaryTree(-9);
		  root.right.left.left.right = new BinaryTree(-91);
		  root.right.left.right = new BinaryTree(5);
		  root.right.left.right.left = new BinaryTree(2);
		  root.right.left.right.right = new BinaryTree(1);
		  root.right.right = new BinaryTree(1);
		  root.right.right.left = new BinaryTree(1);
		  root.right.right.left.left = new BinaryTree(0);
		  root.right.right.left.right = new BinaryTree(1);
		  root.right.right.right = new BinaryTree(1);
		  root.right.right.right.left = new BinaryTree(5);
		  root.right.right.right.right = new BinaryTree(0);
		  chai.expect(program.maxPathSum(root)).to.deep.equal(13);
		});
		it('Test Case #14', function () {
		  const root = new BinaryTree(-2);
		  chai.expect(program.maxPathSum(root)).to.deep.equal(-2);
		});
		it('Test Case #15', function () {
		  const root = new BinaryTree(-2);
		  root.left = new BinaryTree(-1);
		  chai.expect(program.maxPathSum(root)).to.deep.equal(-1);
		});
		it('Test Case #16', function () {
		  const root = new BinaryTree(-2);
		  root.left = new BinaryTree(-1);
		  root.left.left = new BinaryTree(2);
		  root.left.right = new BinaryTree(3);
		  chai.expect(program.maxPathSum(root)).to.deep.equal(4);
		});
		""",
		
		"Heap Sort": """
		const program = require('./program');
		const chai = require('chai');
		
		it('Test Case #1', function () {
		  chai.expect(program.heapSort([8,5,2,9,5,6,3])).to.deep.equal([2,3,5,5,6,8,9]);
		});
		it('Test Case #2', function () {
		  chai.expect(program.heapSort([1])).to.deep.equal([1]);
		});
		it('Test Case #3', function () {
		  chai.expect(program.heapSort([1,2])).to.deep.equal([1,2]);
		});
		it('Test Case #4', function () {
		  chai.expect(program.heapSort([2,1])).to.deep.equal([1,2]);
		});
		it('Test Case #5', function () {
		  chai.expect(program.heapSort([1,3,2])).to.deep.equal([1,2,3]);
		});
		it('Test Case #6', function () {
		  chai.expect(program.heapSort([3,1,2])).to.deep.equal([1,2,3]);
		});
		it('Test Case #7', function () {
		  chai.expect(program.heapSort([1,2,3])).to.deep.equal([1,2,3]);
		});
		it('Test Case #8', function () {
		  chai.expect(program.heapSort([-4,5,10,8,-10,-6,-4,-2,-5,3,5,-4,-5,-1,1,6,-7,-6,-7,8])).to.deep.equal([-10,-7,-7,-6,-6,-5,-5,-4,-4,-4,-2,-1,1,3,5,5,6,8,8,10]);
		});
		it('Test Case #9', function () {
		  chai.expect(program.heapSort([-7,2,3,8,-10,4,-6,-10,-2,-7,10,5,2,9,-9,-5,3,8])).to.deep.equal([-10,-10,-9,-7,-7,-6,-5,-2,2,2,3,3,4,5,8,8,9,10]);
		});
		it('Test Case #10', function () {
		  chai.expect(program.heapSort([8,-6,7,10,8,-1,6,2,4,-5,1,10,8,-10,-9,-10,8,9,-2,7,-2,4])).to.deep.equal([-10,-10,-9,-6,-5,-2,-2,-1,1,2,4,4,6,7,7,8,8,8,8,9,10,10]);
		});
		it('Test Case #11', function () {
		  chai.expect(program.heapSort([5,-2,2,-8,3,-10,-6,-1,2,-2,9,1,1])).to.deep.equal([-10,-8,-6,-2,-2,-1,1,1,2,2,3,5,9]);
		});
		it('Test Case #12', function () {
		  chai.expect(program.heapSort([2,-2,-6,-10,10,4,-8,-1,-8,-4,7,-4,0,9,-9,0,-9,-9,8,1,-4,4,8,5,1,5,0,0,2,-10])).to.deep.equal([-10,-10,-9,-9,-9,-8,-8,-6,-4,-4,-4,-2,-1,0,0,0,0,1,1,2,2,4,4,5,5,7,8,8,9,10]);
		});
		it('Test Case #13', function () {
		  chai.expect(program.heapSort([4,1,5,0,-9,-3,-3,9,3,-4,-9,8,1,-3,-7,-4,-9,-1,-7,-2,-7,4])).to.deep.equal([-9,-9,-9,-7,-7,-7,-4,-4,-3,-3,-3,-2,-1,0,1,1,3,4,4,5,8,9]);
		});
		it('Test Case #14', function () {
		  chai.expect(program.heapSort([427,787,222,996,-359,-614,246,230,107,-706,568,9,-246,12,-764,-212,-484,603,934,-848,-646,-991,661,-32,-348,-474,-439,-56,507,736,635,-171,-215,564,-710,710,565,892,970,-755,55,821,-3,-153,240,-160,-610,-583,-27,131])).to.deep.equal([-991,-848,-764,-755,-710,-706,-646,-614,-610,-583,-484,-474,-439,-359,-348,-246,-215,-212,-171,-160,-153,-56,-32,-27,-3,9,12,55,107,131,222,230,240,246,427,507,564,565,568,603,635,661,710,736,787,821,892,934,970,996]);
		});
		it('Test Case #15', function () {
		  chai.expect(program.heapSort([991,-731,-882,100,280,-43,432,771,-581,180,-382,-998,847,80,-220,680,769,-75,-817,366,956,749,471,228,-435,-269,652,-331,-387,-657,-255,382,-216,-6,-163,-681,980,913,-169,972,-523,354,747,805,382,-827,-796,372,753,519,906])).to.deep.equal([-998,-882,-827,-817,-796,-731,-681,-657,-581,-523,-435,-387,-382,-331,-269,-255,-220,-216,-169,-163,-75,-43,-6,80,100,180,228,280,354,366,372,382,382,432,471,519,652,680,747,749,753,769,771,805,847,906,913,956,972,980,991]);
		});
		it('Test Case #16', function () {
		  chai.expect(program.heapSort([384,-67,120,759,697,232,-7,-557,-772,-987,687,397,-763,-86,-491,947,921,421,825,-679,946,-562,-626,-898,204,776,-343,393,51,-796,-425,31,165,975,-720,878,-785,-367,-609,662,-79,-112,-313,-94,187,260,43,85,-746,612,67,-389,508,777,624,993,-581,34,444,-544,243,-995,432,-755,-978,515,-68,-559,489,732,-19,-489,737,924])).to.deep.equal([-995,-987,-978,-898,-796,-785,-772,-763,-755,-746,-720,-679,-626,-609,-581,-562,-559,-557,-544,-491,-489,-425,-389,-367,-343,-313,-112,-94,-86,-79,-68,-67,-19,-7,31,34,43,51,67,85,120,165,187,204,232,243,260,384,393,397,421,432,444,489,508,515,612,624,662,687,697,732,737,759,776,777,825,878,921,924,946,947,975,993]);
		});
		it('Test Case #17', function () {
		  chai.expect(program.heapSort([544,-578,556,713,-655,-359,-810,-731,194,-531,-685,689,-279,-738,886,-54,-320,-500,738,445,-401,993,-753,329,-396,-924,-975,376,748,-356,972,459,399,669,-488,568,-702,551,763,-90,-249,-45,452,-917,394,195,-877,153,153,788,844,867,266,-739,904,-154,-947,464,343,-312,150,-656,528,61,94,-581])).to.deep.equal([-975,-947,-924,-917,-877,-810,-753,-739,-738,-731,-702,-685,-656,-655,-581,-578,-531,-500,-488,-401,-396,-359,-356,-320,-312,-279,-249,-154,-90,-54,-45,61,94,150,153,153,194,195,266,329,343,376,394,399,445,452,459,464,528,544,551,556,568,669,689,713,738,748,763,788,844,867,886,904,972,993]);
		});
		it('Test Case #18', function () {
		  chai.expect(program.heapSort([-19,759,168,306,270,-602,558,-821,-599,328,753,-50,-568,268,-92,381,-96,730,629,678,-837,351,896,63,-85,437,-453,-991,294,-384,-628,-529,518,613,-319,-519,-220,-67,834,619,802,207,946,-904,295,718,-740,-557,-560,80,296,-90,401,407,798,254,154,387,434,491,228,307,268,505,-415,-976,676,-917,937,-609,593,-36,881,607,121,-373,915,-885,879,391,-158,588,-641,-937,986,949,-321])).to.deep.equal([-991,-976,-937,-917,-904,-885,-837,-821,-740,-641,-628,-609,-602,-599,-568,-560,-557,-529,-519,-453,-415,-384,-373,-321,-319,-220,-158,-96,-92,-90,-85,-67,-50,-36,-19,63,80,121,154,168,207,228,254,268,268,270,294,295,296,306,307,328,351,381,387,391,401,407,434,437,491,505,518,558,588,593,607,613,619,629,676,678,718,730,753,759,798,802,834,879,881,896,915,937,946,949,986]);
		});
		it('Test Case #19', function () {
		  chai.expect(program.heapSort([-823,164,48,-987,323,399,-293,183,-908,-376,14,980,965,842,422,829,59,724,-415,-733,356,-855,-155,52,328,-544,-371,-160,-942,-51,700,-363,-353,-359,238,892,-730,-575,892,490,490,995,572,888,-935,919,-191,646,-120,125,-817,341,-575,372,-874,243,610,-36,-685,-337,-13,295,800,-950,-949,-257,631,-542,201,-796,157,950,540,-846,-265,746,355,-578,-441,-254,-941,-738,-469,-167,-420,-126,-410,59])).to.deep.equal([-987,-950,-949,-942,-941,-935,-908,-874,-855,-846,-823,-817,-796,-738,-733,-730,-685,-578,-575,-575,-544,-542,-469,-441,-420,-415,-410,-376,-371,-363,-359,-353,-337,-293,-265,-257,-254,-191,-167,-160,-155,-126,-120,-51,-36,-13,14,48,52,59,59,125,157,164,183,201,238,243,295,323,328,341,355,356,372,399,422,490,490,540,572,610,631,646,700,724,746,800,829,842,888,892,892,919,950,965,980,995]);
		});
		""",
		
		"Insertion Sort": """
		const program = require('./program');
		const chai = require('chai');
		it('Test Case #1', function () {
		  chai.expect(program.insertionSort([8,5,2,9,5,6,3])).to.deep.equal([2,3,5,5,6,8,9]);
		});
		it('Test Case #2', function () {
		  chai.expect(program.insertionSort([1])).to.deep.equal([1]);
		});
		it('Test Case #3', function () {
		  chai.expect(program.insertionSort([1,2])).to.deep.equal([1,2]);
		});
		it('Test Case #4', function () {
		  chai.expect(program.insertionSort([2,1])).to.deep.equal([1,2]);
		});
		it('Test Case #5', function () {
		  chai.expect(program.insertionSort([1,3,2])).to.deep.equal([1,2,3]);
		});
		it('Test Case #6', function () {
		  chai.expect(program.insertionSort([3,1,2])).to.deep.equal([1,2,3]);
		});
		it('Test Case #7', function () {
		  chai.expect(program.insertionSort([1,2,3])).to.deep.equal([1,2,3]);
		});
		it('Test Case #8', function () {
		  chai.expect(program.insertionSort([-4,5,10,8,-10,-6,-4,-2,-5,3,5,-4,-5,-1,1,6,-7,-6,-7,8])).to.deep.equal([-10,-7,-7,-6,-6,-5,-5,-4,-4,-4,-2,-1,1,3,5,5,6,8,8,10]);
		});
		it('Test Case #9', function () {
		  chai.expect(program.insertionSort([-7,2,3,8,-10,4,-6,-10,-2,-7,10,5,2,9,-9,-5,3,8])).to.deep.equal([-10,-10,-9,-7,-7,-6,-5,-2,2,2,3,3,4,5,8,8,9,10]);
		});
		it('Test Case #10', function () {
		  chai.expect(program.insertionSort([8,-6,7,10,8,-1,6,2,4,-5,1,10,8,-10,-9,-10,8,9,-2,7,-2,4])).to.deep.equal([-10,-10,-9,-6,-5,-2,-2,-1,1,2,4,4,6,7,7,8,8,8,8,9,10,10]);
		});
		it('Test Case #11', function () {
		  chai.expect(program.insertionSort([5,-2,2,-8,3,-10,-6,-1,2,-2,9,1,1])).to.deep.equal([-10,-8,-6,-2,-2,-1,1,1,2,2,3,5,9]);
		});
		it('Test Case #12', function () {
		  chai.expect(program.insertionSort([2,-2,-6,-10,10,4,-8,-1,-8,-4,7,-4,0,9,-9,0,-9,-9,8,1,-4,4,8,5,1,5,0,0,2,-10])).to.deep.equal([-10,-10,-9,-9,-9,-8,-8,-6,-4,-4,-4,-2,-1,0,0,0,0,1,1,2,2,4,4,5,5,7,8,8,9,10]);
		});
		it('Test Case #13', function () {
		  chai.expect(program.insertionSort([4,1,5,0,-9,-3,-3,9,3,-4,-9,8,1,-3,-7,-4,-9,-1,-7,-2,-7,4])).to.deep.equal([-9,-9,-9,-7,-7,-7,-4,-4,-3,-3,-3,-2,-1,0,1,1,3,4,4,5,8,9]);
		});
		it('Test Case #14', function () {
		  chai.expect(program.insertionSort([427,787,222,996,-359,-614,246,230,107,-706,568,9,-246,12,-764,-212,-484,603,934,-848,-646,-991,661,-32,-348,-474,-439,-56,507,736,635,-171,-215,564,-710,710,565,892,970,-755,55,821,-3,-153,240,-160,-610,-583,-27,131])).to.deep.equal([-991,-848,-764,-755,-710,-706,-646,-614,-610,-583,-484,-474,-439,-359,-348,-246,-215,-212,-171,-160,-153,-56,-32,-27,-3,9,12,55,107,131,222,230,240,246,427,507,564,565,568,603,635,661,710,736,787,821,892,934,970,996]);
		});
		it('Test Case #15', function () {
		  chai.expect(program.insertionSort([991,-731,-882,100,280,-43,432,771,-581,180,-382,-998,847,80,-220,680,769,-75,-817,366,956,749,471,228,-435,-269,652,-331,-387,-657,-255,382,-216,-6,-163,-681,980,913,-169,972,-523,354,747,805,382,-827,-796,372,753,519,906])).to.deep.equal([-998,-882,-827,-817,-796,-731,-681,-657,-581,-523,-435,-387,-382,-331,-269,-255,-220,-216,-169,-163,-75,-43,-6,80,100,180,228,280,354,366,372,382,382,432,471,519,652,680,747,749,753,769,771,805,847,906,913,956,972,980,991]);
		});
		it('Test Case #16', function () {
		  chai.expect(program.insertionSort([384,-67,120,759,697,232,-7,-557,-772,-987,687,397,-763,-86,-491,947,921,421,825,-679,946,-562,-626,-898,204,776,-343,393,51,-796,-425,31,165,975,-720,878,-785,-367,-609,662,-79,-112,-313,-94,187,260,43,85,-746,612,67,-389,508,777,624,993,-581,34,444,-544,243,-995,432,-755,-978,515,-68,-559,489,732,-19,-489,737,924])).to.deep.equal([-995,-987,-978,-898,-796,-785,-772,-763,-755,-746,-720,-679,-626,-609,-581,-562,-559,-557,-544,-491,-489,-425,-389,-367,-343,-313,-112,-94,-86,-79,-68,-67,-19,-7,31,34,43,51,67,85,120,165,187,204,232,243,260,384,393,397,421,432,444,489,508,515,612,624,662,687,697,732,737,759,776,777,825,878,921,924,946,947,975,993]);
		});
		it('Test Case #17', function () {
		  chai.expect(program.insertionSort([544,-578,556,713,-655,-359,-810,-731,194,-531,-685,689,-279,-738,886,-54,-320,-500,738,445,-401,993,-753,329,-396,-924,-975,376,748,-356,972,459,399,669,-488,568,-702,551,763,-90,-249,-45,452,-917,394,195,-877,153,153,788,844,867,266,-739,904,-154,-947,464,343,-312,150,-656,528,61,94,-581])).to.deep.equal([-975,-947,-924,-917,-877,-810,-753,-739,-738,-731,-702,-685,-656,-655,-581,-578,-531,-500,-488,-401,-396,-359,-356,-320,-312,-279,-249,-154,-90,-54,-45,61,94,150,153,153,194,195,266,329,343,376,394,399,445,452,459,464,528,544,551,556,568,669,689,713,738,748,763,788,844,867,886,904,972,993]);
		});
		it('Test Case #18', function () {
		  chai.expect(program.insertionSort([-19,759,168,306,270,-602,558,-821,-599,328,753,-50,-568,268,-92,381,-96,730,629,678,-837,351,896,63,-85,437,-453,-991,294,-384,-628,-529,518,613,-319,-519,-220,-67,834,619,802,207,946,-904,295,718,-740,-557,-560,80,296,-90,401,407,798,254,154,387,434,491,228,307,268,505,-415,-976,676,-917,937,-609,593,-36,881,607,121,-373,915,-885,879,391,-158,588,-641,-937,986,949,-321])).to.deep.equal([-991,-976,-937,-917,-904,-885,-837,-821,-740,-641,-628,-609,-602,-599,-568,-560,-557,-529,-519,-453,-415,-384,-373,-321,-319,-220,-158,-96,-92,-90,-85,-67,-50,-36,-19,63,80,121,154,168,207,228,254,268,268,270,294,295,296,306,307,328,351,381,387,391,401,407,434,437,491,505,518,558,588,593,607,613,619,629,676,678,718,730,753,759,798,802,834,879,881,896,915,937,946,949,986]);
		});
		it('Test Case #19', function () {
		  chai.expect(program.insertionSort([-823,164,48,-987,323,399,-293,183,-908,-376,14,980,965,842,422,829,59,724,-415,-733,356,-855,-155,52,328,-544,-371,-160,-942,-51,700,-363,-353,-359,238,892,-730,-575,892,490,490,995,572,888,-935,919,-191,646,-120,125,-817,341,-575,372,-874,243,610,-36,-685,-337,-13,295,800,-950,-949,-257,631,-542,201,-796,157,950,540,-846,-265,746,355,-578,-441,-254,-941,-738,-469,-167,-420,-126,-410,59])).to.deep.equal([-987,-950,-949,-942,-941,-935,-908,-874,-855,-846,-823,-817,-796,-738,-733,-730,-685,-578,-575,-575,-544,-542,-469,-441,-420,-415,-410,-376,-371,-363,-359,-353,-337,-293,-265,-257,-254,-191,-167,-160,-155,-126,-120,-51,-36,-13,14,48,52,59,59,125,157,164,183,201,238,243,295,323,328,341,355,356,372,399,422,490,490,540,572,610,631,646,700,724,746,800,829,842,888,892,892,919,950,965,980,995]);
		});
		""",
		
		"Interweaving Strings": """
		const program = require('./program');
		const chai = require('chai');
		
		it('Test Case #1', function () {
		  const one = "codecomplete";
		  const two = "your-dream-job";
		  const three = "your-codedream-completejob";
		  chai.expect(program.interweavingStrings(one, two, three)).to.deep.equal(true);
		});
		it('Test Case #2', function () {
		  const one = "a";
		  const two = "b";
		  const three = "ab";
		  chai.expect(program.interweavingStrings(one, two, three)).to.deep.equal(true);
		});
		it('Test Case #3', function () {
		  const one = "a";
		  const two = "b";
		  const three = "ba";
		  chai.expect(program.interweavingStrings(one, two, three)).to.deep.equal(true);
		});
		it('Test Case #4', function () {
		  const one = "a";
		  const two = "b";
		  const three = "ac";
		  chai.expect(program.interweavingStrings(one, two, three)).to.deep.equal(false);
		});
		it('Test Case #5', function () {
		  const one = "abc";
		  const two = "def";
		  const three = "abcdef";
		  chai.expect(program.interweavingStrings(one, two, three)).to.deep.equal(true);
		});
		it('Test Case #6', function () {
		  const one = "abc";
		  const two = "def";
		  const three = "adbecf";
		  chai.expect(program.interweavingStrings(one, two, three)).to.deep.equal(true);
		});
		it('Test Case #7', function () {
		  const one = "abc";
		  const two = "def";
		  const three = "deabcf";
		  chai.expect(program.interweavingStrings(one, two, three)).to.deep.equal(true);
		});
		it('Test Case #8', function () {
		  const one = "aabcc";
		  const two = "dbbca";
		  const three = "aadbbcbcac";
		  chai.expect(program.interweavingStrings(one, two, three)).to.deep.equal(true);
		});
		it('Test Case #9', function () {
		  const one = "aabcc";
		  const two = "dbbca";
		  const three = "aadbbbaccc";
		  chai.expect(program.interweavingStrings(one, two, three)).to.deep.equal(false);
		});
		it('Test Case #10', function () {
		  const one = "codecomplete";
		  const two = "your-dream-job";
		  const three = "cyooduerc-odmrpelaemt-ejob";
		  chai.expect(program.interweavingStrings(one, two, three)).to.deep.equal(true);
		});
		it('Test Case #11', function () {
		  const one = "aaaaaaa";
		  const two = "aaaabaaa";
		  const three = "aaaaaaaaaaaaaab";
		  chai.expect(program.interweavingStrings(one, two, three)).to.deep.equal(false);
		});
		it('Test Case #12', function () {
		  const one = "aaaaaaa";
		  const two = "aaaaaaa";
		  const three = "aaaaaaaaaaaaaa";
		  chai.expect(program.interweavingStrings(one, two, three)).to.deep.equal(true);
		});
		it('Test Case #13', function () {
		  const one = "aacaaaa";
		  const two = "aaabaaa";
		  const three = "aaaabacaaaaaaa";
		  chai.expect(program.interweavingStrings(one, two, three)).to.deep.equal(true);
		});
		it('Test Case #14', function () {
		  const one = "aacaaaa";
		  const two = "aaabaaa";
		  const three = "aaaacabaaaaaaa";
		  chai.expect(program.interweavingStrings(one, two, three)).to.deep.equal(true);
		});
		it('Test Case #15', function () {
		  const one = "aacaaaa";
		  const two = "aaabaaa";
		  const three = "aaaaaacbaaaaaa";
		  chai.expect(program.interweavingStrings(one, two, three)).to.deep.equal(false);
		});
		it('Test Case #16', function () {
		  const one = "codecomplete";
		  const two = "your-dream-job";
		  const three = "1your-algodream-expertjob";
		  chai.expect(program.interweavingStrings(one, two, three)).to.deep.equal(false);
		});
		it('Test Case #17', function () {
		  const one = "codecomplete";
		  const two = "your-dream-job";
		  const three = "your-algodream-expertjob1";
		  chai.expect(program.interweavingStrings(one, two, three)).to.deep.equal(false);
		});
		it('Test Case #18', function () {
		  const one = "codecomplete";
		  const two = "your-dream-job";
		  const three = "your-algodream-expertjo";
		  chai.expect(program.interweavingStrings(one, two, three)).to.deep.equal(false);
		});
		it('Test Case #19', function () {
		  const one = "ae";
		  const two = "e";
		  const three = "see";
		  chai.expect(program.interweavingStrings(one, two, three)).to.deep.equal(false);
		});
		""",
		
		"Iterative In-order Traversal": """
		const program = require('./program');
		const chai = require('chai');
		class BinaryTree {
		  constructor(value, parent = null) {
			this.value = value;
			this.left = null;
			this.right = null;
			this.parent = parent;
		  }
		}
		it('Test Case #1', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2, root);
		  root.left.left = new BinaryTree(4, root.left);
		  root.left.left.right = new BinaryTree(9, root.left.left);
		  root.right = new BinaryTree(3, root);
		  root.right.left = new BinaryTree(6, root.right);
		  root.right.right = new BinaryTree(7, root.right);
		  const array = [];
		  function testCallback(tree) {
			if (tree === null) return;
			array.push(tree.value);
		  }
		  program.iterativeInOrderTraversal(root, testCallback);
		  chai.expect(array).to.deep.equal([4,9,2,1,6,3,7]);
		});
		it('Test Case #2', function () {
		  const root = new BinaryTree(1);
		  const array = [];
		  function testCallback(tree) {
			if (tree === null) return;
			array.push(tree.value);
		  }
		  program.iterativeInOrderTraversal(root, testCallback);
		  chai.expect(array).to.deep.equal([1]);
		});
		it('Test Case #3', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2, root);
		  root.left.left = new BinaryTree(4, root.left);
		  root.right = new BinaryTree(3, root);
		  const array = [];
		  function testCallback(tree) {
			if (tree === null) return;
			array.push(tree.value);
		  }
		  program.iterativeInOrderTraversal(root, testCallback);
		  chai.expect(array).to.deep.equal([4,2,1,3]);
		});
		it('Test Case #4', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2, root);
		  root.left.left = new BinaryTree(4, root.left);
		  root.left.right = new BinaryTree(5, root.left);
		  root.right = new BinaryTree(3, root);
		  root.right.left = new BinaryTree(6, root.right);
		  root.right.right = new BinaryTree(7, root.right);
		  const array = [];
		  function testCallback(tree) {
			if (tree === null) return;
			array.push(tree.value);
		  }
		  program.iterativeInOrderTraversal(root, testCallback);
		  chai.expect(array).to.deep.equal([4,2,5,1,6,3,7]);
		});
		it('Test Case #5', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2, root);
		  root.left.left = new BinaryTree(4, root.left);
		  root.left.left.left = new BinaryTree(8, root.left.left);
		  root.left.left.right = new BinaryTree(9, root.left.left);
		  root.left.right = new BinaryTree(5, root.left);
		  root.left.right.left = new BinaryTree(10, root.left.right);
		  root.right = new BinaryTree(3, root);
		  root.right.left = new BinaryTree(6, root.right);
		  root.right.right = new BinaryTree(7, root.right);
		  const array = [];
		  function testCallback(tree) {
			if (tree === null) return;
			array.push(tree.value);
		  }
		  program.iterativeInOrderTraversal(root, testCallback);
		  chai.expect(array).to.deep.equal([8,4,9,2,10,5,1,6,3,7]);
		});
		it('Test Case #6', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2, root);
		  root.left.left = new BinaryTree(4, root.left);
		  root.left.left.left = new BinaryTree(8, root.left.left);
		  root.left.left.right = new BinaryTree(9, root.left.left);
		  root.left.right = new BinaryTree(5, root.left);
		  root.left.right.left = new BinaryTree(10, root.left.right);
		  root.left.right.right = new BinaryTree(11, root.left.right);
		  root.right = new BinaryTree(3, root);
		  root.right.left = new BinaryTree(6, root.right);
		  root.right.left.left = new BinaryTree(12, root.right.left);
		  root.right.left.right = new BinaryTree(13, root.right.left);
		  root.right.right = new BinaryTree(7, root.right);
		  const array = [];
		  function testCallback(tree) {
			if (tree === null) return;
			array.push(tree.value);
		  }
		  program.iterativeInOrderTraversal(root, testCallback);
		  chai.expect(array).to.deep.equal([8,4,9,2,10,5,11,1,12,6,13,3,7]);
		});
		it('Test Case #7', function () {
		  const root = new BinaryTree(1);
		  root.left = new BinaryTree(2, root);
		  root.left.left = new BinaryTree(4, root.left);
		  root.left.left.left = new BinaryTree(8, root.left.left);
		  root.left.left.left.left = new BinaryTree(16, root.left.left.left);
		  root.left.left.left.right = new BinaryTree(17, root.left.left.left);
		  root.left.left.right = new BinaryTree(9, root.left.left);
		  root.left.left.right.left = new BinaryTree(18, root.left.left.right);
		  root.left.right = new BinaryTree(5, root.left);
		  root.left.right.left = new BinaryTree(10, root.left.right);
		  root.left.right.right = new BinaryTree(11, root.left.right);
		  root.right = new BinaryTree(3, root);
		  root.right.left = new BinaryTree(6, root.right);
		  root.right.left.left = new BinaryTree(12, root.right.left);
		  root.right.left.right = new BinaryTree(13, root.right.left);
		  root.right.right = new BinaryTree(7, root.right);
		  root.right.right.left = new BinaryTree(14, root.right.right);
		  root.right.right.right = new BinaryTree(15, root.right.right);
		  const array = [];
		  function testCallback(tree) {
			if (tree === null) return;
			array.push(tree.value);
		  }
		  program.iterativeInOrderTraversal(root, testCallback);
		  chai.expect(array).to.deep.equal([16,8,17,4,18,9,2,10,5,11,1,12,6,13,3,14,7,15]);
		});
		""",
		
		"Kadane's Algorithm": """
		const program = require('./program');
		const chai = require('chai');
		it('Test Case #1', function () {
		  chai.expect(program.kadanesAlgorithm([3,5,-9,1,3,-2,3,4,7,2,-9,6,3,1,-5,4])).to.deep.equal(19);
		});
		it('Test Case #2', function () {
		  chai.expect(program.kadanesAlgorithm([1,2,3,4,5,6,7,8,9,10])).to.deep.equal(55);
		});
		it('Test Case #3', function () {
		  chai.expect(program.kadanesAlgorithm([-1,-2,-3,-4,-5,-6,-7,-8,-9,-10])).to.deep.equal(-1);
		});
		it('Test Case #4', function () {
		  chai.expect(program.kadanesAlgorithm([-10,-2,-9,-4,-8,-6,-7,-1,-3,-5])).to.deep.equal(-1);
		});
		it('Test Case #5', function () {
		  chai.expect(program.kadanesAlgorithm([1,2,3,4,5,6,-20,7,8,9,10])).to.deep.equal(35);
		});
		it('Test Case #6', function () {
		  chai.expect(program.kadanesAlgorithm([1,2,3,4,5,6,-22,7,8,9,10])).to.deep.equal(34);
		});
		it('Test Case #7', function () {
		  chai.expect(program.kadanesAlgorithm([1,2,-4,3,5,-9,8,1,2])).to.deep.equal(11);
		});
		it('Test Case #8', function () {
		  chai.expect(program.kadanesAlgorithm([3,4,-6,7,8])).to.deep.equal(16);
		});
		it('Test Case #9', function () {
		  chai.expect(program.kadanesAlgorithm([8,5,-9,1,3,-2,3,4,7,2,-9,6,3,1,-5,4])).to.deep.equal(23);
		});
		it('Test Case #10', function () {
		  chai.expect(program.kadanesAlgorithm([8,5,-9,1,3,-2,3,4,7,2,-9,6,3,1,-5,6])).to.deep.equal(24);
		});
		it('Test Case #11', function () {
		  chai.expect(program.kadanesAlgorithm([8,5,-9,1,3,-2,3,4,7,2,-18,6,3,1,-5,6])).to.deep.equal(22);
		});
		it('Test Case #12', function () {
		  chai.expect(program.kadanesAlgorithm([8,5,-9,1,3,-2,3,4,7,2,-18,6,3,1,-5,6,20,-23,15,1,-3,4])).to.deep.equal(35);
		});
		it('Test Case #13', function () {
		  chai.expect(program.kadanesAlgorithm([100,8,5,-9,1,3,-2,3,4,7,2,-18,6,3,1,-5,6,20,-23,15,1,-3,4])).to.deep.equal(135);
		});
		it('Test Case #14', function () {
		  chai.expect(program.kadanesAlgorithm([-1000,-1000,2,4,-5,-6,-7,-8,-2,-100])).to.deep.equal(6);
		});
		it('Test Case #15', function () {
		  chai.expect(program.kadanesAlgorithm([-2,-1])).to.deep.equal(-1);
		});
		it('Test Case #16', function () {
		  chai.expect(program.kadanesAlgorithm([-2,1])).to.deep.equal(1);
		});
		""",
		
		"Largest Range": """
		const program = require('./program');
		const chai = require('chai');
		it('Test Case #1', function () {
		  chai.expect(program.largestRange([1,11,3,0,15,5,2,4,10,7,12,6])).to.deep.equal([0,7]);
		});
		it('Test Case #2', function () {
		  chai.expect(program.largestRange([1])).to.deep.equal([1,1]);
		});
		it('Test Case #3', function () {
		  chai.expect(program.largestRange([1,2])).to.deep.equal([1,2]);
		});
		it('Test Case #4', function () {
		  chai.expect(program.largestRange([4,2,1,3])).to.deep.equal([1,4]);
		});
		it('Test Case #5', function () {
		  chai.expect(program.largestRange([4,2,1,3,6])).to.deep.equal([1,4]);
		});
		it('Test Case #6', function () {
		  chai.expect(program.largestRange([8,4,2,10,3,6,7,9,1])).to.deep.equal([6,10]);
		});
		it('Test Case #7', function () {
		  chai.expect(program.largestRange([19,-1,18,17,2,10,3,12,5,16,4,11,8,7,6,15,12,12,2,1,6,13,14])).to.deep.equal([10,19]);
		});
		it('Test Case #8', function () {
		  chai.expect(program.largestRange([0,9,19,-1,18,17,2,10,3,12,5,16,4,11,8,7,6,15,12,12,2,1,6,13,14])).to.deep.equal([-1,19]);
		});
		it('Test Case #9', function () {
		  chai.expect(program.largestRange([0,-5,9,19,-1,18,17,2,-4,-3,10,3,12,5,16,4,11,7,-6,-7,6,15,12,12,2,1,6,13,14,-2])).to.deep.equal([-7,7]);
		});
		it('Test Case #10', function () {
		  chai.expect(program.largestRange([-7,-7,-7,-7,8,-8,0,9,19,-1,-3,18,17,2,10,3,12,5,16,4,11,-6,8,7,6,15,12,12,-5,2,1,6,13,14,-4,-2])).to.deep.equal([-8,19]);
		});
		it('Test Case #11', function () {
		  chai.expect(program.largestRange([1,1,1,3,4])).to.deep.equal([3,4]);
		});
		it('Test Case #12', function () {
		  chai.expect(program.largestRange([-1,0,1])).to.deep.equal([-1,1]);
		});
		""",
		
		"Levenshtein Distance": """
		const program = require('./program');
		const chai = require('chai');
		it('Test Case #1', function () {
		  chai.expect(program.levenshteinDistance("abc", "yabd")).to.deep.equal(2);
		});
		it('Test Case #2', function () {
		  chai.expect(program.levenshteinDistance("", "")).to.deep.equal(0);
		});
		it('Test Case #3', function () {
		  chai.expect(program.levenshteinDistance("", "abc")).to.deep.equal(3);
		});
		it('Test Case #4', function () {
		  chai.expect(program.levenshteinDistance("abc", "abc")).to.deep.equal(0);
		});
		it('Test Case #5', function () {
		  chai.expect(program.levenshteinDistance("abc", "abx")).to.deep.equal(1);
		});
		it('Test Case #6', function () {
		  chai.expect(program.levenshteinDistance("abc", "abcx")).to.deep.equal(1);
		});
		it('Test Case #7', function () {
		  chai.expect(program.levenshteinDistance("abc", "yabcx")).to.deep.equal(2);
		});
		it('Test Case #8', function () {
		  chai.expect(program.levenshteinDistance("codecomplete", "codezcomplete")).to.deep.equal(1);
		});
		it('Test Case #9', function () {
		  chai.expect(program.levenshteinDistance("abcdefghij", "1234567890")).to.deep.equal(10);
		});
		it('Test Case #10', function () {
		  chai.expect(program.levenshteinDistance("abcdefghij", "a234567890")).to.deep.equal(9);
		});
		it('Test Case #11', function () {
		  chai.expect(program.levenshteinDistance("biting", "mitten")).to.deep.equal(4);
		});
		it('Test Case #12', function () {
		  chai.expect(program.levenshteinDistance("cereal", "saturday")).to.deep.equal(6);
		});
		it('Test Case #13', function () {
		  chai.expect(program.levenshteinDistance("cereal", "saturdzz")).to.deep.equal(7);
		});
		it('Test Case #14', function () {
		  chai.expect(program.levenshteinDistance("abbbbbbbbb", "bbbbbbbbba")).to.deep.equal(2);
		});
		it('Test Case #15', function () {
		  chai.expect(program.levenshteinDistance("xabc", "abcx")).to.deep.equal(2);
		});
		it('Test Case #16', function () {
		  chai.expect(program.levenshteinDistance("table", "bal")).to.deep.equal(3);
		});
		it('Test Case #17', function () {
		  chai.expect(program.levenshteinDistance("gumbo", "gambol")).to.deep.equal(2);
		});
		""",
		
		"Max Subset Sum No Adjacent": """
		const program = require('./program');
		const chai = require('chai');
		it('Test Case #1', function () {
		  chai.expect(program.maxSubsetSumNoAdjacent([75,105,120,75,90,135])).to.deep.equal(330);
		});
		it('Test Case #2', function () {
		  chai.expect(program.maxSubsetSumNoAdjacent([])).to.deep.equal(0);
		});
		it('Test Case #3', function () {
		  chai.expect(program.maxSubsetSumNoAdjacent([1])).to.deep.equal(1);
		});
		it('Test Case #4', function () {
		  chai.expect(program.maxSubsetSumNoAdjacent([1,2])).to.deep.equal(2);
		});
		it('Test Case #5', function () {
		  chai.expect(program.maxSubsetSumNoAdjacent([1,2,3])).to.deep.equal(4);
		});
		it('Test Case #6', function () {
		  chai.expect(program.maxSubsetSumNoAdjacent([1,15,3])).to.deep.equal(15);
		});
		it('Test Case #7', function () {
		  chai.expect(program.maxSubsetSumNoAdjacent([7,10,12,7,9,14])).to.deep.equal(33);
		});
		it('Test Case #8', function () {
		  chai.expect(program.maxSubsetSumNoAdjacent([4,3,5,200,5,3])).to.deep.equal(207);
		});
		it('Test Case #9', function () {
		  chai.expect(program.maxSubsetSumNoAdjacent([10,5,20,25,15,5,5,15])).to.deep.equal(60);
		});
		it('Test Case #10', function () {
		  chai.expect(program.maxSubsetSumNoAdjacent([10,5,20,25,15,5,5,15,3,15,5,5,15])).to.deep.equal(90);
		});
		it('Test Case #11', function () {
		  chai.expect(program.maxSubsetSumNoAdjacent([125,210,250,120,150,300])).to.deep.equal(675);
		});
		it('Test Case #12', function () {
		  chai.expect(program.maxSubsetSumNoAdjacent([30,25,50,55,100])).to.deep.equal(180);
		});
		it('Test Case #13', function () {
		  chai.expect(program.maxSubsetSumNoAdjacent([30,25,50,55,100,120])).to.deep.equal(205);
		});
		it('Test Case #14', function () {
		  chai.expect(program.maxSubsetSumNoAdjacent([7,10,12,7,9,14,15,16,25,20,4])).to.deep.equal(72);
		});
		""",
		
		"Merge Sort": """
		const program = require('./program');
		const chai = require('chai');
		it('Test Case #1', function () {
		  chai.expect(program.mergeSort([8,5,2,9,5,6,3])).to.deep.equal([2,3,5,5,6,8,9]);
		});
		it('Test Case #2', function () {
		  chai.expect(program.mergeSort([1])).to.deep.equal([1]);
		});
		it('Test Case #3', function () {
		  chai.expect(program.mergeSort([1,2])).to.deep.equal([1,2]);
		});
		it('Test Case #4', function () {
		  chai.expect(program.mergeSort([2,1])).to.deep.equal([1,2]);
		});
		it('Test Case #5', function () {
		  chai.expect(program.mergeSort([1,3,2])).to.deep.equal([1,2,3]);
		});
		it('Test Case #6', function () {
		  chai.expect(program.mergeSort([3,1,2])).to.deep.equal([1,2,3]);
		});
		it('Test Case #7', function () {
		  chai.expect(program.mergeSort([1,2,3])).to.deep.equal([1,2,3]);
		});
		it('Test Case #8', function () {
		  chai.expect(program.mergeSort([-4,5,10,8,-10,-6,-4,-2,-5,3,5,-4,-5,-1,1,6,-7,-6,-7,8])).to.deep.equal([-10,-7,-7,-6,-6,-5,-5,-4,-4,-4,-2,-1,1,3,5,5,6,8,8,10]);
		});
		it('Test Case #9', function () {
		  chai.expect(program.mergeSort([-7,2,3,8,-10,4,-6,-10,-2,-7,10,5,2,9,-9,-5,3,8])).to.deep.equal([-10,-10,-9,-7,-7,-6,-5,-2,2,2,3,3,4,5,8,8,9,10]);
		});
		it('Test Case #10', function () {
		  chai.expect(program.mergeSort([8,-6,7,10,8,-1,6,2,4,-5,1,10,8,-10,-9,-10,8,9,-2,7,-2,4])).to.deep.equal([-10,-10,-9,-6,-5,-2,-2,-1,1,2,4,4,6,7,7,8,8,8,8,9,10,10]);
		});
		it('Test Case #11', function () {
		  chai.expect(program.mergeSort([5,-2,2,-8,3,-10,-6,-1,2,-2,9,1,1])).to.deep.equal([-10,-8,-6,-2,-2,-1,1,1,2,2,3,5,9]);
		});
		it('Test Case #12', function () {
		  chai.expect(program.mergeSort([2,-2,-6,-10,10,4,-8,-1,-8,-4,7,-4,0,9,-9,0,-9,-9,8,1,-4,4,8,5,1,5,0,0,2,-10])).to.deep.equal([-10,-10,-9,-9,-9,-8,-8,-6,-4,-4,-4,-2,-1,0,0,0,0,1,1,2,2,4,4,5,5,7,8,8,9,10]);
		});
		it('Test Case #13', function () {
		  chai.expect(program.mergeSort([4,1,5,0,-9,-3,-3,9,3,-4,-9,8,1,-3,-7,-4,-9,-1,-7,-2,-7,4])).to.deep.equal([-9,-9,-9,-7,-7,-7,-4,-4,-3,-3,-3,-2,-1,0,1,1,3,4,4,5,8,9]);
		});
		it('Test Case #14', function () {
		  chai.expect(program.mergeSort([427,787,222,996,-359,-614,246,230,107,-706,568,9,-246,12,-764,-212,-484,603,934,-848,-646,-991,661,-32,-348,-474,-439,-56,507,736,635,-171,-215,564,-710,710,565,892,970,-755,55,821,-3,-153,240,-160,-610,-583,-27,131])).to.deep.equal([-991,-848,-764,-755,-710,-706,-646,-614,-610,-583,-484,-474,-439,-359,-348,-246,-215,-212,-171,-160,-153,-56,-32,-27,-3,9,12,55,107,131,222,230,240,246,427,507,564,565,568,603,635,661,710,736,787,821,892,934,970,996]);
		});
		it('Test Case #15', function () {
		  chai.expect(program.mergeSort([991,-731,-882,100,280,-43,432,771,-581,180,-382,-998,847,80,-220,680,769,-75,-817,366,956,749,471,228,-435,-269,652,-331,-387,-657,-255,382,-216,-6,-163,-681,980,913,-169,972,-523,354,747,805,382,-827,-796,372,753,519,906])).to.deep.equal([-998,-882,-827,-817,-796,-731,-681,-657,-581,-523,-435,-387,-382,-331,-269,-255,-220,-216,-169,-163,-75,-43,-6,80,100,180,228,280,354,366,372,382,382,432,471,519,652,680,747,749,753,769,771,805,847,906,913,956,972,980,991]);
		});
		it('Test Case #16', function () {
		  chai.expect(program.mergeSort([384,-67,120,759,697,232,-7,-557,-772,-987,687,397,-763,-86,-491,947,921,421,825,-679,946,-562,-626,-898,204,776,-343,393,51,-796,-425,31,165,975,-720,878,-785,-367,-609,662,-79,-112,-313,-94,187,260,43,85,-746,612,67,-389,508,777,624,993,-581,34,444,-544,243,-995,432,-755,-978,515,-68,-559,489,732,-19,-489,737,924])).to.deep.equal([-995,-987,-978,-898,-796,-785,-772,-763,-755,-746,-720,-679,-626,-609,-581,-562,-559,-557,-544,-491,-489,-425,-389,-367,-343,-313,-112,-94,-86,-79,-68,-67,-19,-7,31,34,43,51,67,85,120,165,187,204,232,243,260,384,393,397,421,432,444,489,508,515,612,624,662,687,697,732,737,759,776,777,825,878,921,924,946,947,975,993]);
		});
		it('Test Case #17', function () {
		  chai.expect(program.mergeSort([544,-578,556,713,-655,-359,-810,-731,194,-531,-685,689,-279,-738,886,-54,-320,-500,738,445,-401,993,-753,329,-396,-924,-975,376,748,-356,972,459,399,669,-488,568,-702,551,763,-90,-249,-45,452,-917,394,195,-877,153,153,788,844,867,266,-739,904,-154,-947,464,343,-312,150,-656,528,61,94,-581])).to.deep.equal([-975,-947,-924,-917,-877,-810,-753,-739,-738,-731,-702,-685,-656,-655,-581,-578,-531,-500,-488,-401,-396,-359,-356,-320,-312,-279,-249,-154,-90,-54,-45,61,94,150,153,153,194,195,266,329,343,376,394,399,445,452,459,464,528,544,551,556,568,669,689,713,738,748,763,788,844,867,886,904,972,993]);
		});
		it('Test Case #18', function () {
		  chai.expect(program.mergeSort([-19,759,168,306,270,-602,558,-821,-599,328,753,-50,-568,268,-92,381,-96,730,629,678,-837,351,896,63,-85,437,-453,-991,294,-384,-628,-529,518,613,-319,-519,-220,-67,834,619,802,207,946,-904,295,718,-740,-557,-560,80,296,-90,401,407,798,254,154,387,434,491,228,307,268,505,-415,-976,676,-917,937,-609,593,-36,881,607,121,-373,915,-885,879,391,-158,588,-641,-937,986,949,-321])).to.deep.equal([-991,-976,-937,-917,-904,-885,-837,-821,-740,-641,-628,-609,-602,-599,-568,-560,-557,-529,-519,-453,-415,-384,-373,-321,-319,-220,-158,-96,-92,-90,-85,-67,-50,-36,-19,63,80,121,154,168,207,228,254,268,268,270,294,295,296,306,307,328,351,381,387,391,401,407,434,437,491,505,518,558,588,593,607,613,619,629,676,678,718,730,753,759,798,802,834,879,881,896,915,937,946,949,986]);
		});
		it('Test Case #19', function () {
		  chai.expect(program.mergeSort([-823,164,48,-987,323,399,-293,183,-908,-376,14,980,965,842,422,829,59,724,-415,-733,356,-855,-155,52,328,-544,-371,-160,-942,-51,700,-363,-353,-359,238,892,-730,-575,892,490,490,995,572,888,-935,919,-191,646,-120,125,-817,341,-575,372,-874,243,610,-36,-685,-337,-13,295,800,-950,-949,-257,631,-542,201,-796,157,950,540,-846,-265,746,355,-578,-441,-254,-941,-738,-469,-167,-420,-126,-410,59])).to.deep.equal([-987,-950,-949,-942,-941,-935,-908,-874,-855,-846,-823,-817,-796,-738,-733,-730,-685,-578,-575,-575,-544,-542,-469,-441,-420,-415,-410,-376,-371,-363,-359,-353,-337,-293,-265,-257,-254,-191,-167,-160,-155,-126,-120,-51,-36,-13,14,48,52,59,59,125,157,164,183,201,238,243,295,323,328,341,355,356,372,399,422,490,490,540,572,610,631,646,700,724,746,800,829,842,888,892,892,919,950,965,980,995]);
		});
		""",
		
		"Number Of Binary Tree Topologies": """
		const program = require('./program');
		const chai = require('chai');
		it('Test Case #1', function () {
		  chai.expect(program.numberOfBinaryTreeTopologies(3)).to.deep.equal(5);
		});
		it('Test Case #2', function () {
		  chai.expect(program.numberOfBinaryTreeTopologies(0)).to.deep.equal(1);
		});
		it('Test Case #3', function () {
		  chai.expect(program.numberOfBinaryTreeTopologies(1)).to.deep.equal(1);
		});
		it('Test Case #4', function () {
		  chai.expect(program.numberOfBinaryTreeTopologies(2)).to.deep.equal(2);
		});
		it('Test Case #5', function () {
		  chai.expect(program.numberOfBinaryTreeTopologies(4)).to.deep.equal(14);
		});
		it('Test Case #6', function () {
		  chai.expect(program.numberOfBinaryTreeTopologies(5)).to.deep.equal(42);
		});
		it('Test Case #7', function () {
		  chai.expect(program.numberOfBinaryTreeTopologies(6)).to.deep.equal(132);
		});
		it('Test Case #8', function () {
		  chai.expect(program.numberOfBinaryTreeTopologies(7)).to.deep.equal(429);
		});
		it('Test Case #9', function () {
		  chai.expect(program.numberOfBinaryTreeTopologies(8)).to.deep.equal(1430);
		});
		it('Test Case #10', function () {
		  chai.expect(program.numberOfBinaryTreeTopologies(9)).to.deep.equal(4862);
		});
		it('Test Case #11', function () {
		  chai.expect(program.numberOfBinaryTreeTopologies(10)).to.deep.equal(16796);
		});
		it('Test Case #12', function () {
		  chai.expect(program.numberOfBinaryTreeTopologies(11)).to.deep.equal(58786);
		});
		it('Test Case #13', function () {
		  chai.expect(program.numberOfBinaryTreeTopologies(12)).to.deep.equal(208012);
		});
		""",
		
		"Permutations": """
		const program = require('./program');
		const chai = require('chai');
		it('Test Case #1', function () {
		  const perms = program.getPermutations([1,2,3]);
		  chai.expect(perms.length).to.deep.equal(6);
		  chai.expect(perms).to.deep.include([1,2,3]);
		  chai.expect(perms).to.deep.include([1,3,2]);
		  chai.expect(perms).to.deep.include([2,1,3]);
		  chai.expect(perms).to.deep.include([2,3,1]);
		  chai.expect(perms).to.deep.include([3,1,2]);
		  chai.expect(perms).to.deep.include([3,2,1]);
		});
		it('Test Case #2', function () {
		  const perms = program.getPermutations([]);
		  chai.expect(perms.length).to.deep.equal(0);
		});
		it('Test Case #3', function () {
		  const perms = program.getPermutations([1]);
		  chai.expect(perms.length).to.deep.equal(1);
		  chai.expect(perms).to.deep.include([1]);
		});
		it('Test Case #4', function () {
		  const perms = program.getPermutations([1,2]);
		  chai.expect(perms.length).to.deep.equal(2);
		  chai.expect(perms).to.deep.include([1,2]);
		  chai.expect(perms).to.deep.include([2,1]);
		});
		it('Test Case #5', function () {
		  const perms = program.getPermutations([1,2,3,4]);
		  chai.expect(perms.length).to.deep.equal(24);
		  chai.expect(perms).to.deep.include([1,2,3,4]);
		  chai.expect(perms).to.deep.include([1,2,4,3]);
		  chai.expect(perms).to.deep.include([1,3,2,4]);
		  chai.expect(perms).to.deep.include([1,3,4,2]);
		  chai.expect(perms).to.deep.include([1,4,2,3]);
		  chai.expect(perms).to.deep.include([1,4,3,2]);
		  chai.expect(perms).to.deep.include([2,1,3,4]);
		  chai.expect(perms).to.deep.include([2,1,4,3]);
		  chai.expect(perms).to.deep.include([2,3,1,4]);
		  chai.expect(perms).to.deep.include([2,3,4,1]);
		  chai.expect(perms).to.deep.include([2,4,1,3]);
		  chai.expect(perms).to.deep.include([2,4,3,1]);
		  chai.expect(perms).to.deep.include([3,1,2,4]);
		  chai.expect(perms).to.deep.include([3,1,4,2]);
		  chai.expect(perms).to.deep.include([3,2,1,4]);
		  chai.expect(perms).to.deep.include([3,2,4,1]);
		  chai.expect(perms).to.deep.include([3,4,1,2]);
		  chai.expect(perms).to.deep.include([3,4,2,1]);
		  chai.expect(perms).to.deep.include([4,1,2,3]);
		  chai.expect(perms).to.deep.include([4,1,3,2]);
		  chai.expect(perms).to.deep.include([4,2,1,3]);
		  chai.expect(perms).to.deep.include([4,2,3,1]);
		  chai.expect(perms).to.deep.include([4,3,1,2]);
		  chai.expect(perms).to.deep.include([4,3,2,1]);
		});
		it('Test Case #6', function () {
		  const perms = program.getPermutations([1,2,3,4,5]);
		  chai.expect(perms.length).to.deep.equal(120);
		  chai.expect(perms).to.deep.include([1,2,3,4,5]);
		  chai.expect(perms).to.deep.include([1,2,3,5,4]);
		  chai.expect(perms).to.deep.include([1,2,4,3,5]);
		  chai.expect(perms).to.deep.include([1,2,4,5,3]);
		  chai.expect(perms).to.deep.include([1,2,5,3,4]);
		  chai.expect(perms).to.deep.include([1,2,5,4,3]);
		  chai.expect(perms).to.deep.include([1,3,2,4,5]);
		  chai.expect(perms).to.deep.include([1,3,2,5,4]);
		  chai.expect(perms).to.deep.include([1,3,4,2,5]);
		  chai.expect(perms).to.deep.include([1,3,4,5,2]);
		  chai.expect(perms).to.deep.include([1,3,5,2,4]);
		  chai.expect(perms).to.deep.include([1,3,5,4,2]);
		  chai.expect(perms).to.deep.include([1,4,2,3,5]);
		  chai.expect(perms).to.deep.include([1,4,2,5,3]);
		  chai.expect(perms).to.deep.include([1,4,3,2,5]);
		  chai.expect(perms).to.deep.include([1,4,3,5,2]);
		  chai.expect(perms).to.deep.include([1,4,5,2,3]);
		  chai.expect(perms).to.deep.include([1,4,5,3,2]);
		  chai.expect(perms).to.deep.include([1,5,2,3,4]);
		  chai.expect(perms).to.deep.include([1,5,2,4,3]);
		  chai.expect(perms).to.deep.include([1,5,3,2,4]);
		  chai.expect(perms).to.deep.include([1,5,3,4,2]);
		  chai.expect(perms).to.deep.include([1,5,4,2,3]);
		  chai.expect(perms).to.deep.include([1,5,4,3,2]);
		  chai.expect(perms).to.deep.include([2,1,3,4,5]);
		  chai.expect(perms).to.deep.include([2,1,3,5,4]);
		  chai.expect(perms).to.deep.include([2,1,4,3,5]);
		  chai.expect(perms).to.deep.include([2,1,4,5,3]);
		  chai.expect(perms).to.deep.include([2,1,5,3,4]);
		  chai.expect(perms).to.deep.include([2,1,5,4,3]);
		  chai.expect(perms).to.deep.include([2,3,1,4,5]);
		  chai.expect(perms).to.deep.include([2,3,1,5,4]);
		  chai.expect(perms).to.deep.include([2,3,4,1,5]);
		  chai.expect(perms).to.deep.include([2,3,4,5,1]);
		  chai.expect(perms).to.deep.include([2,3,5,1,4]);
		  chai.expect(perms).to.deep.include([2,3,5,4,1]);
		  chai.expect(perms).to.deep.include([2,4,1,3,5]);
		  chai.expect(perms).to.deep.include([2,4,1,5,3]);
		  chai.expect(perms).to.deep.include([2,4,3,1,5]);
		  chai.expect(perms).to.deep.include([2,4,3,5,1]);
		  chai.expect(perms).to.deep.include([2,4,5,1,3]);
		  chai.expect(perms).to.deep.include([2,4,5,3,1]);
		  chai.expect(perms).to.deep.include([2,5,1,3,4]);
		  chai.expect(perms).to.deep.include([2,5,1,4,3]);
		  chai.expect(perms).to.deep.include([2,5,3,1,4]);
		  chai.expect(perms).to.deep.include([2,5,3,4,1]);
		  chai.expect(perms).to.deep.include([2,5,4,1,3]);
		  chai.expect(perms).to.deep.include([2,5,4,3,1]);
		  chai.expect(perms).to.deep.include([3,1,2,4,5]);
		  chai.expect(perms).to.deep.include([3,1,2,5,4]);
		  chai.expect(perms).to.deep.include([3,1,4,2,5]);
		  chai.expect(perms).to.deep.include([3,1,4,5,2]);
		  chai.expect(perms).to.deep.include([3,1,5,2,4]);
		  chai.expect(perms).to.deep.include([3,1,5,4,2]);
		  chai.expect(perms).to.deep.include([3,2,1,4,5]);
		  chai.expect(perms).to.deep.include([3,2,1,5,4]);
		  chai.expect(perms).to.deep.include([3,2,4,1,5]);
		  chai.expect(perms).to.deep.include([3,2,4,5,1]);
		  chai.expect(perms).to.deep.include([3,2,5,1,4]);
		  chai.expect(perms).to.deep.include([3,2,5,4,1]);
		  chai.expect(perms).to.deep.include([3,4,1,2,5]);
		  chai.expect(perms).to.deep.include([3,4,1,5,2]);
		  chai.expect(perms).to.deep.include([3,4,2,1,5]);
		  chai.expect(perms).to.deep.include([3,4,2,5,1]);
		  chai.expect(perms).to.deep.include([3,4,5,1,2]);
		  chai.expect(perms).to.deep.include([3,4,5,2,1]);
		  chai.expect(perms).to.deep.include([3,5,1,2,4]);
		  chai.expect(perms).to.deep.include([3,5,1,4,2]);
		  chai.expect(perms).to.deep.include([3,5,2,1,4]);
		  chai.expect(perms).to.deep.include([3,5,2,4,1]);
		  chai.expect(perms).to.deep.include([3,5,4,1,2]);
		  chai.expect(perms).to.deep.include([3,5,4,2,1]);
		  chai.expect(perms).to.deep.include([4,1,2,3,5]);
		  chai.expect(perms).to.deep.include([4,1,2,5,3]);
		  chai.expect(perms).to.deep.include([4,1,3,2,5]);
		  chai.expect(perms).to.deep.include([4,1,3,5,2]);
		  chai.expect(perms).to.deep.include([4,1,5,2,3]);
		  chai.expect(perms).to.deep.include([4,1,5,3,2]);
		  chai.expect(perms).to.deep.include([4,2,1,3,5]);
		  chai.expect(perms).to.deep.include([4,2,1,5,3]);
		  chai.expect(perms).to.deep.include([4,2,3,1,5]);
		  chai.expect(perms).to.deep.include([4,2,3,5,1]);
		  chai.expect(perms).to.deep.include([4,2,5,1,3]);
		  chai.expect(perms).to.deep.include([4,2,5,3,1]);
		  chai.expect(perms).to.deep.include([4,3,1,2,5]);
		  chai.expect(perms).to.deep.include([4,3,1,5,2]);
		  chai.expect(perms).to.deep.include([4,3,2,1,5]);
		  chai.expect(perms).to.deep.include([4,3,2,5,1]);
		  chai.expect(perms).to.deep.include([4,3,5,1,2]);
		  chai.expect(perms).to.deep.include([4,3,5,2,1]);
		  chai.expect(perms).to.deep.include([4,5,1,2,3]);
		  chai.expect(perms).to.deep.include([4,5,1,3,2]);
		  chai.expect(perms).to.deep.include([4,5,2,1,3]);
		  chai.expect(perms).to.deep.include([4,5,2,3,1]);
		  chai.expect(perms).to.deep.include([4,5,3,1,2]);
		  chai.expect(perms).to.deep.include([4,5,3,2,1]);
		  chai.expect(perms).to.deep.include([5,1,2,3,4]);
		  chai.expect(perms).to.deep.include([5,1,2,4,3]);
		  chai.expect(perms).to.deep.include([5,1,3,2,4]);
		  chai.expect(perms).to.deep.include([5,1,3,4,2]);
		  chai.expect(perms).to.deep.include([5,1,4,2,3]);
		  chai.expect(perms).to.deep.include([5,1,4,3,2]);
		  chai.expect(perms).to.deep.include([5,2,1,3,4]);
		  chai.expect(perms).to.deep.include([5,2,1,4,3]);
		  chai.expect(perms).to.deep.include([5,2,3,1,4]);
		  chai.expect(perms).to.deep.include([5,2,3,4,1]);
		  chai.expect(perms).to.deep.include([5,2,4,1,3]);
		  chai.expect(perms).to.deep.include([5,2,4,3,1]);
		  chai.expect(perms).to.deep.include([5,3,1,2,4]);
		  chai.expect(perms).to.deep.include([5,3,1,4,2]);
		  chai.expect(perms).to.deep.include([5,3,2,1,4]);
		  chai.expect(perms).to.deep.include([5,3,2,4,1]);
		  chai.expect(perms).to.deep.include([5,3,4,1,2]);
		  chai.expect(perms).to.deep.include([5,3,4,2,1]);
		  chai.expect(perms).to.deep.include([5,4,1,2,3]);
		  chai.expect(perms).to.deep.include([5,4,1,3,2]);
		  chai.expect(perms).to.deep.include([5,4,2,1,3]);
		  chai.expect(perms).to.deep.include([5,4,2,3,1]);
		  chai.expect(perms).to.deep.include([5,4,3,1,2]);
		  chai.expect(perms).to.deep.include([5,4,3,2,1]);
		});
		""",
		
		"Quick Sort": """
		const program = require('./program');
		const chai = require('chai');
		it('Test Case #1', function () {
		  chai.expect(program.quickSort([8,5,2,9,5,6,3])).to.deep.equal([2,3,5,5,6,8,9]);
		});
		it('Test Case #2', function () {
		  chai.expect(program.quickSort([1])).to.deep.equal([1]);
		});
		it('Test Case #3', function () {
		  chai.expect(program.quickSort([1,2])).to.deep.equal([1,2]);
		});
		it('Test Case #4', function () {
		  chai.expect(program.quickSort([2,1])).to.deep.equal([1,2]);
		});
		it('Test Case #5', function () {
		  chai.expect(program.quickSort([1,3,2])).to.deep.equal([1,2,3]);
		});
		it('Test Case #6', function () {
		  chai.expect(program.quickSort([3,1,2])).to.deep.equal([1,2,3]);
		});
		it('Test Case #7', function () {
		  chai.expect(program.quickSort([1,2,3])).to.deep.equal([1,2,3]);
		});
		it('Test Case #8', function () {
		  chai.expect(program.quickSort([-4,5,10,8,-10,-6,-4,-2,-5,3,5,-4,-5,-1,1,6,-7,-6,-7,8])).to.deep.equal([-10,-7,-7,-6,-6,-5,-5,-4,-4,-4,-2,-1,1,3,5,5,6,8,8,10]);
		});
		it('Test Case #9', function () {
		  chai.expect(program.quickSort([-7,2,3,8,-10,4,-6,-10,-2,-7,10,5,2,9,-9,-5,3,8])).to.deep.equal([-10,-10,-9,-7,-7,-6,-5,-2,2,2,3,3,4,5,8,8,9,10]);
		});
		it('Test Case #10', function () {
		  chai.expect(program.quickSort([8,-6,7,10,8,-1,6,2,4,-5,1,10,8,-10,-9,-10,8,9,-2,7,-2,4])).to.deep.equal([-10,-10,-9,-6,-5,-2,-2,-1,1,2,4,4,6,7,7,8,8,8,8,9,10,10]);
		});
		it('Test Case #11', function () {
		  chai.expect(program.quickSort([5,-2,2,-8,3,-10,-6,-1,2,-2,9,1,1])).to.deep.equal([-10,-8,-6,-2,-2,-1,1,1,2,2,3,5,9]);
		});
		it('Test Case #12', function () {
		  chai.expect(program.quickSort([2,-2,-6,-10,10,4,-8,-1,-8,-4,7,-4,0,9,-9,0,-9,-9,8,1,-4,4,8,5,1,5,0,0,2,-10])).to.deep.equal([-10,-10,-9,-9,-9,-8,-8,-6,-4,-4,-4,-2,-1,0,0,0,0,1,1,2,2,4,4,5,5,7,8,8,9,10]);
		});
		it('Test Case #13', function () {
		  chai.expect(program.quickSort([4,1,5,0,-9,-3,-3,9,3,-4,-9,8,1,-3,-7,-4,-9,-1,-7,-2,-7,4])).to.deep.equal([-9,-9,-9,-7,-7,-7,-4,-4,-3,-3,-3,-2,-1,0,1,1,3,4,4,5,8,9]);
		});
		it('Test Case #14', function () {
		  chai.expect(program.quickSort([427,787,222,996,-359,-614,246,230,107,-706,568,9,-246,12,-764,-212,-484,603,934,-848,-646,-991,661,-32,-348,-474,-439,-56,507,736,635,-171,-215,564,-710,710,565,892,970,-755,55,821,-3,-153,240,-160,-610,-583,-27,131])).to.deep.equal([-991,-848,-764,-755,-710,-706,-646,-614,-610,-583,-484,-474,-439,-359,-348,-246,-215,-212,-171,-160,-153,-56,-32,-27,-3,9,12,55,107,131,222,230,240,246,427,507,564,565,568,603,635,661,710,736,787,821,892,934,970,996]);
		});
		it('Test Case #15', function () {
		  chai.expect(program.quickSort([991,-731,-882,100,280,-43,432,771,-581,180,-382,-998,847,80,-220,680,769,-75,-817,366,956,749,471,228,-435,-269,652,-331,-387,-657,-255,382,-216,-6,-163,-681,980,913,-169,972,-523,354,747,805,382,-827,-796,372,753,519,906])).to.deep.equal([-998,-882,-827,-817,-796,-731,-681,-657,-581,-523,-435,-387,-382,-331,-269,-255,-220,-216,-169,-163,-75,-43,-6,80,100,180,228,280,354,366,372,382,382,432,471,519,652,680,747,749,753,769,771,805,847,906,913,956,972,980,991]);
		});
		it('Test Case #16', function () {
		  chai.expect(program.quickSort([384,-67,120,759,697,232,-7,-557,-772,-987,687,397,-763,-86,-491,947,921,421,825,-679,946,-562,-626,-898,204,776,-343,393,51,-796,-425,31,165,975,-720,878,-785,-367,-609,662,-79,-112,-313,-94,187,260,43,85,-746,612,67,-389,508,777,624,993,-581,34,444,-544,243,-995,432,-755,-978,515,-68,-559,489,732,-19,-489,737,924])).to.deep.equal([-995,-987,-978,-898,-796,-785,-772,-763,-755,-746,-720,-679,-626,-609,-581,-562,-559,-557,-544,-491,-489,-425,-389,-367,-343,-313,-112,-94,-86,-79,-68,-67,-19,-7,31,34,43,51,67,85,120,165,187,204,232,243,260,384,393,397,421,432,444,489,508,515,612,624,662,687,697,732,737,759,776,777,825,878,921,924,946,947,975,993]);
		});
		it('Test Case #17', function () {
		  chai.expect(program.quickSort([544,-578,556,713,-655,-359,-810,-731,194,-531,-685,689,-279,-738,886,-54,-320,-500,738,445,-401,993,-753,329,-396,-924,-975,376,748,-356,972,459,399,669,-488,568,-702,551,763,-90,-249,-45,452,-917,394,195,-877,153,153,788,844,867,266,-739,904,-154,-947,464,343,-312,150,-656,528,61,94,-581])).to.deep.equal([-975,-947,-924,-917,-877,-810,-753,-739,-738,-731,-702,-685,-656,-655,-581,-578,-531,-500,-488,-401,-396,-359,-356,-320,-312,-279,-249,-154,-90,-54,-45,61,94,150,153,153,194,195,266,329,343,376,394,399,445,452,459,464,528,544,551,556,568,669,689,713,738,748,763,788,844,867,886,904,972,993]);
		});
		it('Test Case #18', function () {
		  chai.expect(program.quickSort([-19,759,168,306,270,-602,558,-821,-599,328,753,-50,-568,268,-92,381,-96,730,629,678,-837,351,896,63,-85,437,-453,-991,294,-384,-628,-529,518,613,-319,-519,-220,-67,834,619,802,207,946,-904,295,718,-740,-557,-560,80,296,-90,401,407,798,254,154,387,434,491,228,307,268,505,-415,-976,676,-917,937,-609,593,-36,881,607,121,-373,915,-885,879,391,-158,588,-641,-937,986,949,-321])).to.deep.equal([-991,-976,-937,-917,-904,-885,-837,-821,-740,-641,-628,-609,-602,-599,-568,-560,-557,-529,-519,-453,-415,-384,-373,-321,-319,-220,-158,-96,-92,-90,-85,-67,-50,-36,-19,63,80,121,154,168,207,228,254,268,268,270,294,295,296,306,307,328,351,381,387,391,401,407,434,437,491,505,518,558,588,593,607,613,619,629,676,678,718,730,753,759,798,802,834,879,881,896,915,937,946,949,986]);
		});
		it('Test Case #19', function () {
		  chai.expect(program.quickSort([-823,164,48,-987,323,399,-293,183,-908,-376,14,980,965,842,422,829,59,724,-415,-733,356,-855,-155,52,328,-544,-371,-160,-942,-51,700,-363,-353,-359,238,892,-730,-575,892,490,490,995,572,888,-935,919,-191,646,-120,125,-817,341,-575,372,-874,243,610,-36,-685,-337,-13,295,800,-950,-949,-257,631,-542,201,-796,157,950,540,-846,-265,746,355,-578,-441,-254,-941,-738,-469,-167,-420,-126,-410,59])).to.deep.equal([-987,-950,-949,-942,-941,-935,-908,-874,-855,-846,-823,-817,-796,-738,-733,-730,-685,-578,-575,-575,-544,-542,-469,-441,-420,-415,-410,-376,-371,-363,-359,-353,-337,-293,-265,-257,-254,-191,-167,-160,-155,-126,-120,-51,-36,-13,14,48,52,59,59,125,157,164,183,201,238,243,295,323,328,341,355,356,372,399,422,490,490,540,572,610,631,646,700,724,746,800,829,842,888,892,892,919,950,965,980,995]);
		});
		""",
		
		"Selection Sort": """
		const program = require('./program');
		const chai = require('chai');
		it('Test Case #1', function () {
		  chai.expect(program.selectionSort([8,5,2,9,5,6,3])).to.deep.equal([2,3,5,5,6,8,9]);
		});
		it('Test Case #2', function () {
		  chai.expect(program.selectionSort([1])).to.deep.equal([1]);
		});
		it('Test Case #3', function () {
		  chai.expect(program.selectionSort([1,2])).to.deep.equal([1,2]);
		});
		it('Test Case #4', function () {
		  chai.expect(program.selectionSort([2,1])).to.deep.equal([1,2]);
		});
		it('Test Case #5', function () {
		  chai.expect(program.selectionSort([1,3,2])).to.deep.equal([1,2,3]);
		});
		it('Test Case #6', function () {
		  chai.expect(program.selectionSort([3,1,2])).to.deep.equal([1,2,3]);
		});
		it('Test Case #7', function () {
		  chai.expect(program.selectionSort([1,2,3])).to.deep.equal([1,2,3]);
		});
		it('Test Case #8', function () {
		  chai.expect(program.selectionSort([-4,5,10,8,-10,-6,-4,-2,-5,3,5,-4,-5,-1,1,6,-7,-6,-7,8])).to.deep.equal([-10,-7,-7,-6,-6,-5,-5,-4,-4,-4,-2,-1,1,3,5,5,6,8,8,10]);
		});
		it('Test Case #9', function () {
		  chai.expect(program.selectionSort([-7,2,3,8,-10,4,-6,-10,-2,-7,10,5,2,9,-9,-5,3,8])).to.deep.equal([-10,-10,-9,-7,-7,-6,-5,-2,2,2,3,3,4,5,8,8,9,10]);
		});
		it('Test Case #10', function () {
		  chai.expect(program.selectionSort([8,-6,7,10,8,-1,6,2,4,-5,1,10,8,-10,-9,-10,8,9,-2,7,-2,4])).to.deep.equal([-10,-10,-9,-6,-5,-2,-2,-1,1,2,4,4,6,7,7,8,8,8,8,9,10,10]);
		});
		it('Test Case #11', function () {
		  chai.expect(program.selectionSort([5,-2,2,-8,3,-10,-6,-1,2,-2,9,1,1])).to.deep.equal([-10,-8,-6,-2,-2,-1,1,1,2,2,3,5,9]);
		});
		it('Test Case #12', function () {
		  chai.expect(program.selectionSort([2,-2,-6,-10,10,4,-8,-1,-8,-4,7,-4,0,9,-9,0,-9,-9,8,1,-4,4,8,5,1,5,0,0,2,-10])).to.deep.equal([-10,-10,-9,-9,-9,-8,-8,-6,-4,-4,-4,-2,-1,0,0,0,0,1,1,2,2,4,4,5,5,7,8,8,9,10]);
		});
		it('Test Case #13', function () {
		  chai.expect(program.selectionSort([4,1,5,0,-9,-3,-3,9,3,-4,-9,8,1,-3,-7,-4,-9,-1,-7,-2,-7,4])).to.deep.equal([-9,-9,-9,-7,-7,-7,-4,-4,-3,-3,-3,-2,-1,0,1,1,3,4,4,5,8,9]);
		});
		it('Test Case #14', function () {
		  chai.expect(program.selectionSort([427,787,222,996,-359,-614,246,230,107,-706,568,9,-246,12,-764,-212,-484,603,934,-848,-646,-991,661,-32,-348,-474,-439,-56,507,736,635,-171,-215,564,-710,710,565,892,970,-755,55,821,-3,-153,240,-160,-610,-583,-27,131])).to.deep.equal([-991,-848,-764,-755,-710,-706,-646,-614,-610,-583,-484,-474,-439,-359,-348,-246,-215,-212,-171,-160,-153,-56,-32,-27,-3,9,12,55,107,131,222,230,240,246,427,507,564,565,568,603,635,661,710,736,787,821,892,934,970,996]);
		});
		it('Test Case #15', function () {
		  chai.expect(program.selectionSort([991,-731,-882,100,280,-43,432,771,-581,180,-382,-998,847,80,-220,680,769,-75,-817,366,956,749,471,228,-435,-269,652,-331,-387,-657,-255,382,-216,-6,-163,-681,980,913,-169,972,-523,354,747,805,382,-827,-796,372,753,519,906])).to.deep.equal([-998,-882,-827,-817,-796,-731,-681,-657,-581,-523,-435,-387,-382,-331,-269,-255,-220,-216,-169,-163,-75,-43,-6,80,100,180,228,280,354,366,372,382,382,432,471,519,652,680,747,749,753,769,771,805,847,906,913,956,972,980,991]);
		});
		it('Test Case #16', function () {
		  chai.expect(program.selectionSort([384,-67,120,759,697,232,-7,-557,-772,-987,687,397,-763,-86,-491,947,921,421,825,-679,946,-562,-626,-898,204,776,-343,393,51,-796,-425,31,165,975,-720,878,-785,-367,-609,662,-79,-112,-313,-94,187,260,43,85,-746,612,67,-389,508,777,624,993,-581,34,444,-544,243,-995,432,-755,-978,515,-68,-559,489,732,-19,-489,737,924])).to.deep.equal([-995,-987,-978,-898,-796,-785,-772,-763,-755,-746,-720,-679,-626,-609,-581,-562,-559,-557,-544,-491,-489,-425,-389,-367,-343,-313,-112,-94,-86,-79,-68,-67,-19,-7,31,34,43,51,67,85,120,165,187,204,232,243,260,384,393,397,421,432,444,489,508,515,612,624,662,687,697,732,737,759,776,777,825,878,921,924,946,947,975,993]);
		});
		it('Test Case #17', function () {
		  chai.expect(program.selectionSort([544,-578,556,713,-655,-359,-810,-731,194,-531,-685,689,-279,-738,886,-54,-320,-500,738,445,-401,993,-753,329,-396,-924,-975,376,748,-356,972,459,399,669,-488,568,-702,551,763,-90,-249,-45,452,-917,394,195,-877,153,153,788,844,867,266,-739,904,-154,-947,464,343,-312,150,-656,528,61,94,-581])).to.deep.equal([-975,-947,-924,-917,-877,-810,-753,-739,-738,-731,-702,-685,-656,-655,-581,-578,-531,-500,-488,-401,-396,-359,-356,-320,-312,-279,-249,-154,-90,-54,-45,61,94,150,153,153,194,195,266,329,343,376,394,399,445,452,459,464,528,544,551,556,568,669,689,713,738,748,763,788,844,867,886,904,972,993]);
		});
		it('Test Case #18', function () {
		  chai.expect(program.selectionSort([-19,759,168,306,270,-602,558,-821,-599,328,753,-50,-568,268,-92,381,-96,730,629,678,-837,351,896,63,-85,437,-453,-991,294,-384,-628,-529,518,613,-319,-519,-220,-67,834,619,802,207,946,-904,295,718,-740,-557,-560,80,296,-90,401,407,798,254,154,387,434,491,228,307,268,505,-415,-976,676,-917,937,-609,593,-36,881,607,121,-373,915,-885,879,391,-158,588,-641,-937,986,949,-321])).to.deep.equal([-991,-976,-937,-917,-904,-885,-837,-821,-740,-641,-628,-609,-602,-599,-568,-560,-557,-529,-519,-453,-415,-384,-373,-321,-319,-220,-158,-96,-92,-90,-85,-67,-50,-36,-19,63,80,121,154,168,207,228,254,268,268,270,294,295,296,306,307,328,351,381,387,391,401,407,434,437,491,505,518,558,588,593,607,613,619,629,676,678,718,730,753,759,798,802,834,879,881,896,915,937,946,949,986]);
		});
		it('Test Case #19', function () {
		  chai.expect(program.selectionSort([-823,164,48,-987,323,399,-293,183,-908,-376,14,980,965,842,422,829,59,724,-415,-733,356,-855,-155,52,328,-544,-371,-160,-942,-51,700,-363,-353,-359,238,892,-730,-575,892,490,490,995,572,888,-935,919,-191,646,-120,125,-817,341,-575,372,-874,243,610,-36,-685,-337,-13,295,800,-950,-949,-257,631,-542,201,-796,157,950,540,-846,-265,746,355,-578,-441,-254,-941,-738,-469,-167,-420,-126,-410,59])).to.deep.equal([-987,-950,-949,-942,-941,-935,-908,-874,-855,-846,-823,-817,-796,-738,-733,-730,-685,-578,-575,-575,-544,-542,-469,-441,-420,-415,-410,-376,-371,-363,-359,-353,-337,-293,-265,-257,-254,-191,-167,-160,-155,-126,-120,-51,-36,-13,14,48,52,59,59,125,157,164,183,201,238,243,295,323,328,341,355,356,372,399,422,490,490,540,572,610,631,646,700,724,746,800,829,842,888,892,892,919,950,965,980,995]);
		});
		""",
		
		"Flatten Binary Tree": """
		const program = require('./program');
		const chai = require('chai');
		class StartingBinaryTree {
		  constructor(value) {
			this.value = value;
			this.left = null;
			this.right = null;
		  }
		}
		class BinaryTreeExtended extends StartingBinaryTree {
			constructor(value) {
			  super(value);
			}
			insert(values, i = 0) {
			  if (i >= values.length) return;
			  const queue = [this];
			  while (queue.length > 0) {
				let current = queue.shift();
				if (current.left === null) {
				  current.left = new BinaryTree(values[i]);
				  break;
				}
				queue.push(current.left);
				if (current.right === null) {
				  current.right = new BinaryTree(values[i]);
				  break;
				}
				queue.push(current.right);
			  }
			  this.insert(values, i + 1);
			  return this;
			}
			leftToRightToLeft() {
			  const nodes = [];
			  let current = this;
			  while (current.right !== null) {
				nodes.push(current.value);
				current = current.right;
			  }
			  nodes.push(current.value);
			  while (current !== null) {
				nodes.push(current.value);
				current = current.left;
			  }
			  return nodes;
			}
		}
		it('Test Case #1', function () {
		  const root = new BinaryTreeExtended(1);
		  root.left = new BinaryTreeExtended(2);
		  root.left.left = new BinaryTreeExtended(4);
		  root.left.right = new BinaryTreeExtended(5);
		  root.left.right.left = new BinaryTreeExtended(7);
		  root.left.right.right = new BinaryTreeExtended(8);
		  root.right = new BinaryTreeExtended(3);
		  root.right.left = new BinaryTreeExtended(6);
		  const leftMostNode = program.flattenBinaryTree(root);
		  const leftToRightToLeft = leftMostNode.leftToRightToLeft();
		  const expected = [4,2,7,5,8,1,6,3,3,6,1,8,5,7,2,4]
		  chai.expect(leftToRightToLeft).to.deep.equal(expected);
		});
		it('Test Case #2', function () {
		  const root = new BinaryTreeExtended(1);
		  const leftMostNode = program.flattenBinaryTree(root);
		  const leftToRightToLeft = leftMostNode.leftToRightToLeft();
		  const expected = [1, 1]
		  chai.expect(leftToRightToLeft).to.deep.equal(expected);
		});
		it('Test Case #3', function () {
		  const root = new BinaryTreeExtended(1);
		  root.left = new BinaryTreeExtended(2);
		  const leftMostNode = program.flattenBinaryTree(root);
		  const leftToRightToLeft = leftMostNode.leftToRightToLeft();
		  const expected = [2, 1, 1, 2]
		  chai.expect(leftToRightToLeft).to.deep.equal(expected);
		});
		it('Test Case #4', function () {
		  const root = new BinaryTreeExtended(1);
		  root.left = new BinaryTreeExtended(2);
		  root.right = new BinaryTreeExtended(3);
		  const leftMostNode = program.flattenBinaryTree(root);
		  const leftToRightToLeft = leftMostNode.leftToRightToLeft();
		  const expected = [2, 1, 3, 3, 1, 2]
		  chai.expect(leftToRightToLeft).to.deep.equal(expected);
		});
		it('Test Case #5', function () {
		  const root = new BinaryTreeExtended(1);
		  root.left = new BinaryTreeExtended(2);
		  root.left.left = new BinaryTreeExtended(4);
		  root.right = new BinaryTreeExtended(3);
		  const leftMostNode = program.flattenBinaryTree(root);
		  const leftToRightToLeft = leftMostNode.leftToRightToLeft();
		  const expected = [4, 2, 1, 3, 3, 1, 2, 4]
		  chai.expect(leftToRightToLeft).to.deep.equal(expected);
		});
		it('Test Case #6', function () {
		  const root = new BinaryTreeExtended(1);
		  root.left = new BinaryTreeExtended(2);
		  root.left.left = new BinaryTreeExtended(4);
		  root.left.right = new BinaryTreeExtended(5);
		  root.right = new BinaryTreeExtended(3);
		  const leftMostNode = program.flattenBinaryTree(root);
		  const leftToRightToLeft = leftMostNode.leftToRightToLeft();
		  const expected = [4, 2, 5, 1, 3, 3, 1, 5, 2, 4]
		  chai.expect(leftToRightToLeft).to.deep.equal(expected);
		});
		it('Test Case #7', function () {
		  const root = new BinaryTreeExtended(1);
		  root.left = new BinaryTreeExtended(2);
		  root.left.left = new BinaryTreeExtended(4);
		  root.left.right = new BinaryTreeExtended(5);
		  root.right = new BinaryTreeExtended(3);
		  root.right.left = new BinaryTreeExtended(6);
		  const leftMostNode = program.flattenBinaryTree(root);
		  const leftToRightToLeft = leftMostNode.leftToRightToLeft();
		  const expected = [4, 2, 5, 1, 6, 3, 3, 6, 1, 5, 2, 4]
		  chai.expect(leftToRightToLeft).to.deep.equal(expected);
		});
		it('Test Case #8', function () {
		  const root = new BinaryTreeExtended(1);
		  root.left = new BinaryTreeExtended(2);
		  root.left.left = new BinaryTreeExtended(4);
		  root.left.left.left = new BinaryTreeExtended(8);
		  root.left.left.right = new BinaryTreeExtended(9);
		  root.left.right = new BinaryTreeExtended(5);
		  root.left.right.left = new BinaryTreeExtended(10);
		  root.left.right.right = new BinaryTreeExtended(11);
		  root.right = new BinaryTreeExtended(3);
		  root.right.left = new BinaryTreeExtended(6);
		  root.right.left.left = new BinaryTreeExtended(12);
		  root.right.right = new BinaryTreeExtended(7);
		  const leftMostNode = program.flattenBinaryTree(root);
		  const leftToRightToLeft = leftMostNode.leftToRightToLeft();
		  const expected = [8,4,9,2,10,5,11,1,12,6,3,7,7,3,6,12,1,11,5,10,2,9,4,8]
		  chai.expect(leftToRightToLeft).to.deep.equal(expected);
		});
		""",
		
		"BST Traversal": """
		const program = require('./program');
		const chai = require('chai');
		class BST {
		  constructor(value) {
			this.value = value;
			this.left = null;
			this.right = null;
		  }
		}
		it('Test Case #1', function () {
		  const root = new BST(10);
		  root.left = new BST(5);
		  root.left.left = new BST(2);
		  root.left.left.left = new BST(1);
		  root.left.right = new BST(5);
		  root.right = new BST(15);
		  root.right.right = new BST(22);
		  chai.expect(program.inOrderTraverse(root, [])).to.deep.equal([1,2,5,5,10,15,22]);
		  chai.expect(program.preOrderTraverse(root, [])).to.deep.equal([10,5,2,1,5,15,22]);
		  chai.expect(program.postOrderTraverse(root, [])).to.deep.equal([1,2,5,5,22,15,10]);
		});
		it('Test Case #2', function () {
		  const root = new BST(100);
		  root.left = new BST(5);
		  root.left.left = new BST(2);
		  root.left.left.left = new BST(1);
		  root.left.left.left.left = new BST(-51);
		  root.left.left.left.left.left = new BST(-403);
		  root.left.left.left.right = new BST(1);
		  root.left.left.left.right.right = new BST(1);
		  root.left.left.left.right.right.right = new BST(1);
		  root.left.left.left.right.right.right.right = new BST(1);
		  root.left.left.right = new BST(3);
		  root.left.right = new BST(15);
		  root.left.right.left = new BST(5);
		  root.left.right.right = new BST(22);
		  root.left.right.right.right = new BST(57);
		  root.left.right.right.right.right = new BST(60);
		  root.right = new BST(502);
		  root.right.left = new BST(204);
		  root.right.left.left = new BST(203);
		  root.right.left.right = new BST(205);
		  root.right.left.right.right = new BST(207);
		  root.right.left.right.right.left = new BST(206);
		  root.right.left.right.right.right = new BST(208);
		  root.right.right = new BST(55000);
		  root.right.right.left = new BST(1001);
		  root.right.right.left.right = new BST(4500);
		  chai.expect(program.inOrderTraverse(root, [])).to.deep.equal([-403,-51,1,1,1,1,1,2,3,5,5,15,22,57,60,100,203,204,205,206,207,208,502,1001,4500,55000]);
		  chai.expect(program.preOrderTraverse(root, [])).to.deep.equal([100,5,2,1,-51,-403,1,1,1,1,3,15,5,22,57,60,502,204,203,205,207,206,208,55000,1001,4500]);
		  chai.expect(program.postOrderTraverse(root, [])).to.deep.equal([-403,-51,1,1,1,1,1,3,2,5,60,57,22,15,5,203,206,208,207,205,204,4500,1001,55000,502,100]);
		});
		it('Test Case #3', function () {
		  const root = new BST(10);
		  root.left = new BST(5);
		  root.left.left = new BST(2);
		  root.left.left.left = new BST(1);
		  root.left.left.left.left = new BST(-5);
		  root.left.left.left.left.left = new BST(-15);
		  root.left.left.left.left.left.left = new BST(-22);
		  root.left.left.left.left.right = new BST(-5);
		  root.left.left.left.left.right.right = new BST(-2);
		  root.left.left.left.left.right.right.right = new BST(-1);
		  root.left.right = new BST(5);
		  root.right = new BST(15);
		  root.right.right = new BST(22);
		  chai.expect(program.inOrderTraverse(root, [])).to.deep.equal([-22,-15,-5,-5,-2,-1,1,2,5,5,10,15,22]);
		  chai.expect(program.preOrderTraverse(root, [])).to.deep.equal([10,5,2,1,-5,-15,-22,-5,-2,-1,5,15,22]);
		  chai.expect(program.postOrderTraverse(root, [])).to.deep.equal([-22,-15,-1,-2,-5,-5,1,2,5,5,22,15,10]);
		});
		it('Test Case #4', function () {
		  const root = new BST(10);
		  chai.expect(program.inOrderTraverse(root, [])).to.deep.equal([10]);
		  chai.expect(program.preOrderTraverse(root, [])).to.deep.equal([10]);
		  chai.expect(program.postOrderTraverse(root, [])).to.deep.equal([10]);
		});
		it('Test Case #5', function () {
		  const root = new BST(10);
		  root.left = new BST(5);
		  root.left.left = new BST(2);
		  root.left.left.left = new BST(1);
		  root.left.right = new BST(5);
		  root.right = new BST(15);
		  root.right.right = new BST(22);
		  root.right.right.right = new BST(500);
		  root.right.right.right.left = new BST(50);
		  root.right.right.right.left.right = new BST(200);
		  root.right.right.right.right = new BST(1500);
		  root.right.right.right.right.right = new BST(10000);
		  root.right.right.right.right.right.left = new BST(2200);
		  chai.expect(program.inOrderTraverse(root, [])).to.deep.equal([1,2,5,5,10,15,22,50,200,500,1500,2200,10000]);
		  chai.expect(program.preOrderTraverse(root, [])).to.deep.equal([10,5,2,1,5,15,22,500,50,200,1500,10000,2200]);
		  chai.expect(program.postOrderTraverse(root, [])).to.deep.equal([1,2,5,5,200,50,2200,10000,1500,500,22,15,10]);
		});
		it('Test Case #6', function () {
		  const root = new BST(5000);
		  root.left = new BST(5);
		  root.left.left = new BST(2);
		  root.left.left.left = new BST(1);
		  root.left.left.left.right = new BST(1);
		  root.left.left.left.right.right = new BST(1);
		  root.left.left.left.right.right.right = new BST(1);
		  root.left.left.left.right.right.right.right = new BST(1);
		  root.left.left.right = new BST(3);
		  root.left.right = new BST(15);
		  root.left.right.left = new BST(5);
		  root.left.right.right = new BST(22);
		  root.left.right.right.right = new BST(502);
		  root.left.right.right.right.left = new BST(204);
		  root.left.right.right.right.left.left = new BST(203);
		  root.left.right.right.right.left.right = new BST(205);
		  root.left.right.right.right.left.right.right = new BST(207);
		  root.left.right.right.right.left.right.right.left = new BST(206);
		  root.left.right.right.right.left.right.right.right = new BST(208);
		  root.right = new BST(55000);
		  chai.expect(program.inOrderTraverse(root, [])).to.deep.equal([1,1,1,1,1,2,3,5,5,15,22,203,204,205,206,207,208,502,5000,55000]);
		  chai.expect(program.preOrderTraverse(root, [])).to.deep.equal([5000,5,2,1,1,1,1,1,3,15,5,22,502,204,203,205,207,206,208,55000]);
		  chai.expect(program.postOrderTraverse(root, [])).to.deep.equal([1,1,1,1,1,3,2,5,203,206,208,207,205,204,502,22,15,5,55000,5000]);
		});
		""",
		
		"Move Element To End": """
		const program = require('./program');
		const chai = require('chai');

		function sorted(array) {
			return array.sort(function(a, b) {
				return a - b;
			});
		}
		
		it('Test Case #1', function () {
		  const array = [];
		  const toMove = 3;
		  const expected = [];
		  const output = program.moveElementToEnd(array, toMove);
		  chai.expect(output).to.deep.equal(expected);
		});

		it('Test Case #2', function () {
		  const array = [1, 2, 4, 5, 6];
		  const toMove = 3;
		  const expected = [1, 2, 4, 5, 6];
		  const output = sorted(program.moveElementToEnd(array, toMove));
		  chai.expect(output).to.deep.equal(expected);
		});

		it('Test Case #3', function () {
		  const array = [3, 3, 3, 3, 3];
		  const toMove = 3;
		  const expected = [3, 3, 3, 3, 3];
		  const output = program.moveElementToEnd(array, toMove);
		  chai.expect(output).to.deep.equal(expected);
		});

		it('Test Case #4', function () {
		  const array = [3, 1, 2, 4, 5];
		  const toMove = 3;
		  const expectedStart = [1, 2, 4, 5];
		  const expectedEnd = [3];
		  const output = program.moveElementToEnd(array, toMove);
		  const outputStart = sorted(output.slice(0, 4));
		  const outputEnd = output.slice(4);
		  chai.expect(outputStart).to.deep.equal(expectedStart);
		  chai.expect(outputEnd).to.deep.equal(expectedEnd);
		});

		it('Test Case #5', function () {
		  const array = [1, 2, 4, 5, 3];
		  const toMove = 3;
		  const expectedStart = [1, 2, 4, 5];
		  const expectedEnd = [3];
		  const output = program.moveElementToEnd(array, toMove);
		  const outputStart = sorted(output.slice(0, 4));
		  const outputEnd = output.slice(4);
		  chai.expect(outputStart).to.deep.equal(expectedStart);
		  chai.expect(outputEnd).to.deep.equal(expectedEnd);
		});

		it('Test Case #6', function () {
		  const array = [1, 2, 3, 4, 5];
		  const toMove = 3;
		  const expectedStart = [1, 2, 4, 5];
		  const expectedEnd = [3];
		  const output = program.moveElementToEnd(array, toMove);
		  const outputStart = sorted(output.slice(0, 4));
		  const outputEnd = output.slice(4);
		  chai.expect(outputStart).to.deep.equal(expectedStart);
		  chai.expect(outputEnd).to.deep.equal(expectedEnd);
		});

		it('Test Case #7', function () {
		  const array = [5, 5, 5, 5, 5, 5, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12];
		  const toMove = 5;
		  const expectedStart = [1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12];
		  const expectedEnd = [5, 5, 5, 5, 5, 5];
		  const output = program.moveElementToEnd(array, toMove);
		  const outputStart = sorted(output.slice(0, 11));
		  const outputEnd = output.slice(11);
		  chai.expect(outputStart).to.deep.equal(expectedStart);
		  chai.expect(outputEnd).to.deep.equal(expectedEnd);
		});

		it('Test Case #8', function () {
		  const array = [1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12, 5, 5, 5, 5, 5, 5];
		  const toMove = 5;
		  const expectedStart = [1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12];
		  const expectedEnd = [5, 5, 5, 5, 5, 5];
		  const output = program.moveElementToEnd(array, toMove);
		  const outputStart = sorted(output.slice(0, 11));
		  const outputEnd = output.slice(11);
		  chai.expect(outputStart).to.deep.equal(expectedStart);
		  chai.expect(outputEnd).to.deep.equal(expectedEnd);
		});

		it('Test Case #9', function () {
		  const array = [5, 1, 2, 5, 5, 3, 4, 6, 7, 5, 8, 9, 10, 11, 5, 5, 12];
		  const toMove = 5;
		  const expectedStart = [1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12];
		  const expectedEnd = [5, 5, 5, 5, 5, 5];
		  const output = program.moveElementToEnd(array, toMove);
		  const outputStart = sorted(output.slice(0, 11));
		  const outputEnd = output.slice(11);
		  chai.expect(outputStart).to.deep.equal(expectedStart);
		  chai.expect(outputEnd).to.deep.equal(expectedEnd);
		});

		it('Test Case #10', function () {
		  const array = [2, 1, 2, 2, 2, 3, 4, 2];
		  const toMove = 2;
		  const expectedStart = [1, 3, 4];
		  const expectedEnd = [2, 2, 2, 2, 2];
		  const output = program.moveElementToEnd(array, toMove);
		  const outputStart = sorted(output.slice(0, 3));
		  const outputEnd = output.slice(3);
		  chai.expect(outputStart).to.deep.equal(expectedStart);
		  chai.expect(outputEnd).to.deep.equal(expectedEnd);
		});
		""",
		
		"Youngest Common Ancestor": """
		const program = require('./program');
		const chai = require('chai');
		class AncestralTree extends program.AncestralTree {
			constructor(name) {
				super(name);
			}
			addAsAncestor(descendants) {
				for (const descendant of descendants) {
					descendant.ancestor = this;
				}
			}
		}
		function getTrees() {
			const trees = {};
			const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
			for (const letter of ALPHABET) {
				trees[letter] = new AncestralTree(letter);
			}
			return trees;
		}
		it('Test Case #1', function () {
		  const trees = getTrees();
		  trees["A"].addAsAncestor([trees["B"], trees["C"]]);
		  trees["B"].addAsAncestor([trees["D"], trees["E"]]);
		  trees["C"].addAsAncestor([trees["F"], trees["G"]]);
		  trees["D"].addAsAncestor([trees["H"], trees["I"]]);
		  const yca = program.getYoungestCommonAncestor(trees["A"], trees["E"], trees["I"]);
		  chai.expect(yca).to.deep.equal(trees["B"]);
		});
		it('Test Case #2', function () {
		  const trees = getTrees();
		  trees["A"].addAsAncestor([trees["B"], trees["C"], trees["D"], trees["E"], trees["F"]]);
		  trees["B"].addAsAncestor([trees["G"], trees["H"], trees["I"]]);
		  trees["C"].addAsAncestor([trees["J"]]);
		  trees["D"].addAsAncestor([trees["K"], trees["L"]]);
		  trees["F"].addAsAncestor([trees["M"], trees["N"]]);
		  trees["H"].addAsAncestor([trees["O"], trees["P"], trees["Q"], trees["R"]]);
		  trees["K"].addAsAncestor([trees["S"]]);
		  trees["P"].addAsAncestor([trees["T"], trees["U"]]);
		  trees["R"].addAsAncestor([trees["V"]]);
		  trees["V"].addAsAncestor([trees["W"], trees["X"], trees["Y"]]);
		  trees["X"].addAsAncestor([trees["Z"]]);
		  const yca = program.getYoungestCommonAncestor(trees["A"], trees["A"], trees["B"]);
		  chai.expect(yca).to.deep.equal(trees["A"]);
		});
		it('Test Case #3', function () {
		  const trees = getTrees();
		  trees["A"].addAsAncestor([trees["B"], trees["C"], trees["D"], trees["E"], trees["F"]]);
		  trees["B"].addAsAncestor([trees["G"], trees["H"], trees["I"]]);
		  trees["C"].addAsAncestor([trees["J"]]);
		  trees["D"].addAsAncestor([trees["K"], trees["L"]]);
		  trees["F"].addAsAncestor([trees["M"], trees["N"]]);
		  trees["H"].addAsAncestor([trees["O"], trees["P"], trees["Q"], trees["R"]]);
		  trees["K"].addAsAncestor([trees["S"]]);
		  trees["P"].addAsAncestor([trees["T"], trees["U"]]);
		  trees["R"].addAsAncestor([trees["V"]]);
		  trees["V"].addAsAncestor([trees["W"], trees["X"], trees["Y"]]);
		  trees["X"].addAsAncestor([trees["Z"]]);
		  const yca = program.getYoungestCommonAncestor(trees["A"], trees["B"], trees["F"]);
		  chai.expect(yca).to.deep.equal(trees["A"]);
		});
		it('Test Case #4', function () {
		  const trees = getTrees();
		  trees["A"].addAsAncestor([trees["B"], trees["C"], trees["D"], trees["E"], trees["F"]]);
		  trees["B"].addAsAncestor([trees["G"], trees["H"], trees["I"]]);
		  trees["C"].addAsAncestor([trees["J"]]);
		  trees["D"].addAsAncestor([trees["K"], trees["L"]]);
		  trees["F"].addAsAncestor([trees["M"], trees["N"]]);
		  trees["H"].addAsAncestor([trees["O"], trees["P"], trees["Q"], trees["R"]]);
		  trees["K"].addAsAncestor([trees["S"]]);
		  trees["P"].addAsAncestor([trees["T"], trees["U"]]);
		  trees["R"].addAsAncestor([trees["V"]]);
		  trees["V"].addAsAncestor([trees["W"], trees["X"], trees["Y"]]);
		  trees["X"].addAsAncestor([trees["Z"]]);
		  const yca = program.getYoungestCommonAncestor(trees["A"], trees["G"], trees["M"]);
		  chai.expect(yca).to.deep.equal(trees["A"]);
		});
		it('Test Case #5', function () {
		  const trees = getTrees();
		  trees["A"].addAsAncestor([trees["B"], trees["C"], trees["D"], trees["E"], trees["F"]]);
		  trees["B"].addAsAncestor([trees["G"], trees["H"], trees["I"]]);
		  trees["C"].addAsAncestor([trees["J"]]);
		  trees["D"].addAsAncestor([trees["K"], trees["L"]]);
		  trees["F"].addAsAncestor([trees["M"], trees["N"]]);
		  trees["H"].addAsAncestor([trees["O"], trees["P"], trees["Q"], trees["R"]]);
		  trees["K"].addAsAncestor([trees["S"]]);
		  trees["P"].addAsAncestor([trees["T"], trees["U"]]);
		  trees["R"].addAsAncestor([trees["V"]]);
		  trees["V"].addAsAncestor([trees["W"], trees["X"], trees["Y"]]);
		  trees["X"].addAsAncestor([trees["Z"]]);
		  const yca = program.getYoungestCommonAncestor(trees["A"], trees["U"], trees["S"]);
		  chai.expect(yca).to.deep.equal(trees["A"]);
		});
		it('Test Case #6', function () {
		  const trees = getTrees();
		  trees["A"].addAsAncestor([trees["B"], trees["C"], trees["D"], trees["E"], trees["F"]]);
		  trees["B"].addAsAncestor([trees["G"], trees["H"], trees["I"]]);
		  trees["C"].addAsAncestor([trees["J"]]);
		  trees["D"].addAsAncestor([trees["K"], trees["L"]]);
		  trees["F"].addAsAncestor([trees["M"], trees["N"]]);
		  trees["H"].addAsAncestor([trees["O"], trees["P"], trees["Q"], trees["R"]]);
		  trees["K"].addAsAncestor([trees["S"]]);
		  trees["P"].addAsAncestor([trees["T"], trees["U"]]);
		  trees["R"].addAsAncestor([trees["V"]]);
		  trees["V"].addAsAncestor([trees["W"], trees["X"], trees["Y"]]);
		  trees["X"].addAsAncestor([trees["Z"]]);
		  const yca = program.getYoungestCommonAncestor(trees["A"], trees["Z"], trees["M"]);
		  chai.expect(yca).to.deep.equal(trees["A"]);
		});
		it('Test Case #7', function () {
		  const trees = getTrees();
		  trees["A"].addAsAncestor([trees["B"], trees["C"], trees["D"], trees["E"], trees["F"]]);
		  trees["B"].addAsAncestor([trees["G"], trees["H"], trees["I"]]);
		  trees["C"].addAsAncestor([trees["J"]]);
		  trees["D"].addAsAncestor([trees["K"], trees["L"]]);
		  trees["F"].addAsAncestor([trees["M"], trees["N"]]);
		  trees["H"].addAsAncestor([trees["O"], trees["P"], trees["Q"], trees["R"]]);
		  trees["K"].addAsAncestor([trees["S"]]);
		  trees["P"].addAsAncestor([trees["T"], trees["U"]]);
		  trees["R"].addAsAncestor([trees["V"]]);
		  trees["V"].addAsAncestor([trees["W"], trees["X"], trees["Y"]]);
		  trees["X"].addAsAncestor([trees["Z"]]);
		  const yca = program.getYoungestCommonAncestor(trees["A"], trees["O"], trees["I"]);
		  chai.expect(yca).to.deep.equal(trees["B"]);
		});
		it('Test Case #8', function () {
		  const trees = getTrees();
		  trees["A"].addAsAncestor([trees["B"], trees["C"], trees["D"], trees["E"], trees["F"]]);
		  trees["B"].addAsAncestor([trees["G"], trees["H"], trees["I"]]);
		  trees["C"].addAsAncestor([trees["J"]]);
		  trees["D"].addAsAncestor([trees["K"], trees["L"]]);
		  trees["F"].addAsAncestor([trees["M"], trees["N"]]);
		  trees["H"].addAsAncestor([trees["O"], trees["P"], trees["Q"], trees["R"]]);
		  trees["K"].addAsAncestor([trees["S"]]);
		  trees["P"].addAsAncestor([trees["T"], trees["U"]]);
		  trees["R"].addAsAncestor([trees["V"]]);
		  trees["V"].addAsAncestor([trees["W"], trees["X"], trees["Y"]]);
		  trees["X"].addAsAncestor([trees["Z"]]);
		  const yca = program.getYoungestCommonAncestor(trees["A"], trees["T"], trees["Z"]);
		  chai.expect(yca).to.deep.equal(trees["H"]);
		});
		it('Test Case #9', function () {
		  const trees = getTrees();
		  trees["A"].addAsAncestor([trees["B"], trees["C"], trees["D"], trees["E"], trees["F"]]);
		  trees["B"].addAsAncestor([trees["G"], trees["H"], trees["I"]]);
		  trees["C"].addAsAncestor([trees["J"]]);
		  trees["D"].addAsAncestor([trees["K"], trees["L"]]);
		  trees["F"].addAsAncestor([trees["M"], trees["N"]]);
		  trees["H"].addAsAncestor([trees["O"], trees["P"], trees["Q"], trees["R"]]);
		  trees["K"].addAsAncestor([trees["S"]]);
		  trees["P"].addAsAncestor([trees["T"], trees["U"]]);
		  trees["R"].addAsAncestor([trees["V"]]);
		  trees["V"].addAsAncestor([trees["W"], trees["X"], trees["Y"]]);
		  trees["X"].addAsAncestor([trees["Z"]]);
		  const yca = program.getYoungestCommonAncestor(trees["A"], trees["T"], trees["V"]);
		  chai.expect(yca).to.deep.equal(trees["H"]);
		});
		it('Test Case #10', function () {
		  const trees = getTrees();
		  trees["A"].addAsAncestor([trees["B"], trees["C"], trees["D"], trees["E"], trees["F"]]);
		  trees["B"].addAsAncestor([trees["G"], trees["H"], trees["I"]]);
		  trees["C"].addAsAncestor([trees["J"]]);
		  trees["D"].addAsAncestor([trees["K"], trees["L"]]);
		  trees["F"].addAsAncestor([trees["M"], trees["N"]]);
		  trees["H"].addAsAncestor([trees["O"], trees["P"], trees["Q"], trees["R"]]);
		  trees["K"].addAsAncestor([trees["S"]]);
		  trees["P"].addAsAncestor([trees["T"], trees["U"]]);
		  trees["R"].addAsAncestor([trees["V"]]);
		  trees["V"].addAsAncestor([trees["W"], trees["X"], trees["Y"]]);
		  trees["X"].addAsAncestor([trees["Z"]]);
		  const yca = program.getYoungestCommonAncestor(trees["A"], trees["T"], trees["H"]);
		  chai.expect(yca).to.deep.equal(trees["H"]);
		});
		it('Test Case #11', function () {
		  const trees = getTrees();
		  trees["A"].addAsAncestor([trees["B"], trees["C"], trees["D"], trees["E"], trees["F"]]);
		  trees["B"].addAsAncestor([trees["G"], trees["H"], trees["I"]]);
		  trees["C"].addAsAncestor([trees["J"]]);
		  trees["D"].addAsAncestor([trees["K"], trees["L"]]);
		  trees["F"].addAsAncestor([trees["M"], trees["N"]]);
		  trees["H"].addAsAncestor([trees["O"], trees["P"], trees["Q"], trees["R"]]);
		  trees["K"].addAsAncestor([trees["S"]]);
		  trees["P"].addAsAncestor([trees["T"], trees["U"]]);
		  trees["R"].addAsAncestor([trees["V"]]);
		  trees["V"].addAsAncestor([trees["W"], trees["X"], trees["Y"]]);
		  trees["X"].addAsAncestor([trees["Z"]]);
		  const yca = program.getYoungestCommonAncestor(trees["A"], trees["W"], trees["V"]);
		  chai.expect(yca).to.deep.equal(trees["V"]);
		});
		it('Test Case #12', function () {
		  const trees = getTrees();
		  trees["A"].addAsAncestor([trees["B"], trees["C"], trees["D"], trees["E"], trees["F"]]);
		  trees["B"].addAsAncestor([trees["G"], trees["H"], trees["I"]]);
		  trees["C"].addAsAncestor([trees["J"]]);
		  trees["D"].addAsAncestor([trees["K"], trees["L"]]);
		  trees["F"].addAsAncestor([trees["M"], trees["N"]]);
		  trees["H"].addAsAncestor([trees["O"], trees["P"], trees["Q"], trees["R"]]);
		  trees["K"].addAsAncestor([trees["S"]]);
		  trees["P"].addAsAncestor([trees["T"], trees["U"]]);
		  trees["R"].addAsAncestor([trees["V"]]);
		  trees["V"].addAsAncestor([trees["W"], trees["X"], trees["Y"]]);
		  trees["X"].addAsAncestor([trees["Z"]]);
		  const yca = program.getYoungestCommonAncestor(trees["A"], trees["Z"], trees["B"]);
		  chai.expect(yca).to.deep.equal(trees["B"]);
		});
		it('Test Case #13', function () {
		  const trees = getTrees();
		  trees["A"].addAsAncestor([trees["B"], trees["C"], trees["D"], trees["E"], trees["F"]]);
		  trees["B"].addAsAncestor([trees["G"], trees["H"], trees["I"]]);
		  trees["C"].addAsAncestor([trees["J"]]);
		  trees["D"].addAsAncestor([trees["K"], trees["L"]]);
		  trees["F"].addAsAncestor([trees["M"], trees["N"]]);
		  trees["H"].addAsAncestor([trees["O"], trees["P"], trees["Q"], trees["R"]]);
		  trees["K"].addAsAncestor([trees["S"]]);
		  trees["P"].addAsAncestor([trees["T"], trees["U"]]);
		  trees["R"].addAsAncestor([trees["V"]]);
		  trees["V"].addAsAncestor([trees["W"], trees["X"], trees["Y"]]);
		  trees["X"].addAsAncestor([trees["Z"]]);
		  const yca = program.getYoungestCommonAncestor(trees["A"], trees["Q"], trees["W"]);
		  chai.expect(yca).to.deep.equal(trees["H"]);
		});
		it('Test Case #14', function () {
		  const trees = getTrees();
		  trees["A"].addAsAncestor([trees["B"], trees["C"], trees["D"], trees["E"], trees["F"]]);
		  trees["B"].addAsAncestor([trees["G"], trees["H"], trees["I"]]);
		  trees["C"].addAsAncestor([trees["J"]]);
		  trees["D"].addAsAncestor([trees["K"], trees["L"]]);
		  trees["F"].addAsAncestor([trees["M"], trees["N"]]);
		  trees["H"].addAsAncestor([trees["O"], trees["P"], trees["Q"], trees["R"]]);
		  trees["K"].addAsAncestor([trees["S"]]);
		  trees["P"].addAsAncestor([trees["T"], trees["U"]]);
		  trees["R"].addAsAncestor([trees["V"]]);
		  trees["V"].addAsAncestor([trees["W"], trees["X"], trees["Y"]]);
		  trees["X"].addAsAncestor([trees["Z"]]);
		  const yca = program.getYoungestCommonAncestor(trees["A"], trees["A"], trees["Z"]);
		  chai.expect(yca).to.deep.equal(trees["A"]);
		});
		""",
		
		"Suffix Trie Construction": """
		const program = require('./program');
		const chai = require('chai');
		it('Test Case #1', function () {
		  const trie = new program.SuffixTrie("babc");
		  const expected = {"a":{"b":{"c":{"*":true}}},"b":{"a":{"b":{"c":{"*":true}}},"c":{"*":true}},"c":{"*":true}};
		  chai.expect(trie.root).to.deep.equal(expected);
		  chai.expect(trie.contains("abc")).to.deep.equal(true);
		});
		it('Test Case #2', function () {
		  const trie = new program.SuffixTrie("test");
		  const expected = {"e":{"s":{"t":{"*":true}}},"s":{"t":{"*":true}},"t":{"*":true,"e":{"s":{"t":{"*":true}}}}};
		  chai.expect(trie.root).to.deep.equal(expected);
		  chai.expect(trie.contains("t")).to.deep.equal(true);
		  chai.expect(trie.contains("st")).to.deep.equal(true);
		  chai.expect(trie.contains("est")).to.deep.equal(true);
		  chai.expect(trie.contains("test")).to.deep.equal(true);
		  chai.expect(trie.contains("tes")).to.deep.equal(false);
		});
		it('Test Case #3', function () {
		  const trie = new program.SuffixTrie("invisible");
		  const expected = {"b":{"l":{"e":{"*":true}}},"e":{"*":true},"i":{"b":{"l":{"e":{"*":true}}},"n":{"v":{"i":{"s":{"i":{"b":{"l":{"e":{"*":true}}}}}}}},"s":{"i":{"b":{"l":{"e":{"*":true}}}}}},"l":{"e":{"*":true}},"n":{"v":{"i":{"s":{"i":{"b":{"l":{"e":{"*":true}}}}}}}},"s":{"i":{"b":{"l":{"e":{"*":true}}}}},"v":{"i":{"s":{"i":{"b":{"l":{"e":{"*":true}}}}}}}};
		  chai.expect(trie.root).to.deep.equal(expected);
		  chai.expect(trie.contains("e")).to.deep.equal(true);
		  chai.expect(trie.contains("le")).to.deep.equal(true);
		  chai.expect(trie.contains("ble")).to.deep.equal(true);
		  chai.expect(trie.contains("ible")).to.deep.equal(true);
		  chai.expect(trie.contains("sible")).to.deep.equal(true);
		  chai.expect(trie.contains("isible")).to.deep.equal(true);
		  chai.expect(trie.contains("visible")).to.deep.equal(true);
		  chai.expect(trie.contains("nvisible")).to.deep.equal(true);
		  chai.expect(trie.contains("invisible")).to.deep.equal(true);
		  chai.expect(trie.contains("nvisibl")).to.deep.equal(false);
		});
		it('Test Case #4', function () {
		  const trie = new program.SuffixTrie("1234556789");
		  const expected = {"1":{"2":{"3":{"4":{"5":{"5":{"6":{"7":{"8":{"9":{"*":true}}}}}}}}}},"2":{"3":{"4":{"5":{"5":{"6":{"7":{"8":{"9":{"*":true}}}}}}}}},"3":{"4":{"5":{"5":{"6":{"7":{"8":{"9":{"*":true}}}}}}}},"4":{"5":{"5":{"6":{"7":{"8":{"9":{"*":true}}}}}}},"5":{"5":{"6":{"7":{"8":{"9":{"*":true}}}}},"6":{"7":{"8":{"9":{"*":true}}}}},"6":{"7":{"8":{"9":{"*":true}}}},"7":{"8":{"9":{"*":true}}},"8":{"9":{"*":true}},"9":{"*":true}};
		  chai.expect(trie.root).to.deep.equal(expected);
		  chai.expect(trie.contains("9")).to.deep.equal(true);
		  chai.expect(trie.contains("89")).to.deep.equal(true);
		  chai.expect(trie.contains("789")).to.deep.equal(true);
		  chai.expect(trie.contains("6789")).to.deep.equal(true);
		  chai.expect(trie.contains("56789")).to.deep.equal(true);
		  chai.expect(trie.contains("456789")).to.deep.equal(false);
		  chai.expect(trie.contains("3456789")).to.deep.equal(false);
		  chai.expect(trie.contains("23456789")).to.deep.equal(false);
		  chai.expect(trie.contains("123456789")).to.deep.equal(false);
		  chai.expect(trie.contains("45567")).to.deep.equal(false);
		});
		it('Test Case #5', function () {
		  const trie = new program.SuffixTrie("testtest");
		  const expected = {"e":{"s":{"t":{"*":true,"t":{"e":{"s":{"t":{"*":true}}}}}}},"s":{"t":{"*":true,"t":{"e":{"s":{"t":{"*":true}}}}}},"t":{"*":true,"e":{"s":{"t":{"*":true,"t":{"e":{"s":{"t":{"*":true}}}}}}},"t":{"e":{"s":{"t":{"*":true}}}}}};
		  chai.expect(trie.root).to.deep.equal(expected);
		  chai.expect(trie.contains("t")).to.deep.equal(true);
		  chai.expect(trie.contains("st")).to.deep.equal(true);
		  chai.expect(trie.contains("est")).to.deep.equal(true);
		  chai.expect(trie.contains("test")).to.deep.equal(true);
		  chai.expect(trie.contains("ttest")).to.deep.equal(true);
		  chai.expect(trie.contains("sttest")).to.deep.equal(true);
		  chai.expect(trie.contains("esttest")).to.deep.equal(true);
		  chai.expect(trie.contains("testtest")).to.deep.equal(true);
		  chai.expect(trie.contains("tt")).to.deep.equal(false);
		});
		it('Test Case #6', function () {
		  const trie = new program.SuffixTrie("ttttttttt");
		  const expected = {"t":{"*":true,"t":{"*":true,"t":{"*":true,"t":{"*":true,"t":{"*":true,"t":{"*":true,"t":{"*":true,"t":{"*":true,"t":{"*":true}}}}}}}}}};
		  chai.expect(trie.root).to.deep.equal(expected);
		  chai.expect(trie.contains("t")).to.deep.equal(true);
		  chai.expect(trie.contains("tt")).to.deep.equal(true);
		  chai.expect(trie.contains("ttt")).to.deep.equal(true);
		  chai.expect(trie.contains("tttt")).to.deep.equal(true);
		  chai.expect(trie.contains("ttttt")).to.deep.equal(true);
		  chai.expect(trie.contains("tttttt")).to.deep.equal(true);
		  chai.expect(trie.contains("ttttttt")).to.deep.equal(true);
		  chai.expect(trie.contains("tttttttt")).to.deep.equal(true);
		  chai.expect(trie.contains("ttttttttt")).to.deep.equal(true);
		  chai.expect(trie.contains("vvv")).to.deep.equal(false);
		});
		""",
		
		"Right Sibling Tree": """
		const program = require('./program');
		const chai = require('chai');
		class BinaryTree {
		  constructor(value) {
			this.value = value;
			this.left = null;
			this.right = null;
		  }
		  getDfsOrder(values) {
			values.push(this.value);
			if (this.left !== null) {
			  this.left.getDfsOrder(values);
			}
			if (this.right !== null) {
			  this.right.getDfsOrder(values);
			}
			return values;
		  }
		}
		  it('Test Case #1', function () {
			const root = new BinaryTree(1);
			root.left = new BinaryTree(2);
			root.left.left = new BinaryTree(4);
			root.left.left.left = new BinaryTree(8);
			root.left.left.right = new BinaryTree(9);
			root.left.right = new BinaryTree(5);
			root.left.right.right = new BinaryTree(10);
			root.right = new BinaryTree(3);
			root.right.left = new BinaryTree(6);
			root.right.left.left = new BinaryTree(11);
			root.right.left.left.left = new BinaryTree(14);
			root.right.right = new BinaryTree(7);
			root.right.right.left = new BinaryTree(12);
			root.right.right.right = new BinaryTree(13);
			const mutatedRoot = program.rightSiblingTree(root);
			const dfsOrder = mutatedRoot.getDfsOrder([]);
			const expected = [1, 2, 4, 8, 9, 5, 6, 11, 14, 7, 12, 13, 3, 6, 11, 14, 7, 12, 13];
			chai.expect(dfsOrder).to.deep.equal(expected);
		  });
		  it('Test Case #2', function () {
			const root = new BinaryTree(1);
			const mutatedRoot = program.rightSiblingTree(root);
			const dfsOrder = mutatedRoot.getDfsOrder([]);
			const expected = [1]
			chai.expect(dfsOrder).to.deep.equal(expected);
		  });
		  it('Test Case #3', function () {
			const root = new BinaryTree(1);
			root.left = new BinaryTree(2);
			const mutatedRoot = program.rightSiblingTree(root);
			const dfsOrder = mutatedRoot.getDfsOrder([]);
			const expected = [1,2]
			chai.expect(dfsOrder).to.deep.equal(expected);
		  });
		  it('Test Case #4', function () {
			const root = new BinaryTree(1);
			root.left = new BinaryTree(2);
			root.right = new BinaryTree(3);
			const mutatedRoot = program.rightSiblingTree(root);
			const dfsOrder = mutatedRoot.getDfsOrder([]);
			const expected = [1,2,3]
			chai.expect(dfsOrder).to.deep.equal(expected);
		});
		it('Test Case #5', function () {
			const root = new BinaryTree(1);
			root.left = new BinaryTree(2);
			root.left.left = new BinaryTree(4);
			root.right = new BinaryTree(3);
			const mutatedRoot = program.rightSiblingTree(root);
			const dfsOrder = mutatedRoot.getDfsOrder([]);
			const expected = [1, 2, 4, 3]
			chai.expect(dfsOrder).to.deep.equal(expected);
		  });
		  it('Test Case #6', function () {
			const root = new BinaryTree(1);
			root.left = new BinaryTree(2);
			root.left.left = new BinaryTree(4);
			root.left.right = new BinaryTree(5);
			root.right = new BinaryTree(3);
			const mutatedRoot = program.rightSiblingTree(root);
			const dfsOrder = mutatedRoot.getDfsOrder([]);
			const expected = [1, 2, 4, 5, 3];
			chai.expect(dfsOrder).to.deep.equal(expected);
		  });
		  it('Test Case #7', function () {
			const root = new BinaryTree(1);
			root.left = new BinaryTree(2);
			root.left.left = new BinaryTree(4);
			root.left.right = new BinaryTree(5);
			root.right = new BinaryTree(3);
			root.right.left = new BinaryTree(6);
			const mutatedRoot = program.rightSiblingTree(root);
			const dfsOrder = mutatedRoot.getDfsOrder([]);
			const expected = [1, 2, 4, 5, 6, 3, 6]
			chai.expect(dfsOrder).to.deep.equal(expected);
		  });
		  it('Test Case #8', function () {
			const root = new BinaryTree(1);
			root.left = new BinaryTree(2);
			root.left.left = new BinaryTree(4);
			root.left.right = new BinaryTree(5);
			root.left.right.left = new BinaryTree(7);
			root.left.right.right = new BinaryTree(8);
			root.right = new BinaryTree(3);
			root.right.left = new BinaryTree(6);
			const mutatedRoot = program.rightSiblingTree(root);
			const dfsOrder = mutatedRoot.getDfsOrder([]);
			const expected = [1, 2, 4, 5, 7, 8, 6, 3, 6]
			chai.expect(dfsOrder).to.deep.equal(expected);
		  });
		  it('Test Case #9', function () {
			const root = new BinaryTree(1);
			root.left = new BinaryTree(2);
			root.left.left = new BinaryTree(4);
			root.left.left.left = new BinaryTree(8);
			root.left.left.right = new BinaryTree(9);
			root.left.right = new BinaryTree(5);
			root.left.right.left = new BinaryTree(10);
			root.left.right.right = new BinaryTree(11);
			root.right = new BinaryTree(3);
			root.right.left = new BinaryTree(6);
			root.right.left.left = new BinaryTree(12);
			root.right.left.right = new BinaryTree(13);
			root.right.right = new BinaryTree(7);
			root.right.right.left = new BinaryTree(14);
			root.right.right.right = new BinaryTree(15);
			const mutatedRoot = program.rightSiblingTree(root);
			const dfsOrder = mutatedRoot.getDfsOrder([]);
			const expected = [1, 2, 4, 8, 9, 10, 11, 12, 13, 14, 15, 5, 10, 11, 12, 13, 14, 15, 6, 12, 13, 14, 15, 7, 14, 15, 3, 6, 12, 13, 14, 15, 7, 14, 15]
			chai.expect(dfsOrder).to.deep.equal(expected);
		  });
		""",
		
		"Powerset": """
		const program = require('./program');
		const chai = require('chai');
		function sortAndStringify(array) {
			return array.sort(function(a, b) { return a - b; }).join(',');
		}
		it('Test Case #1', function () {
		  const output = program.powerset([1,2,3]).map(sortAndStringify);
		  chai.expect(output.length === 8).to.be.true;
		  chai.expect(output).to.include("");
		  chai.expect(output).to.include("1");
		  chai.expect(output).to.include("2");
		  chai.expect(output).to.include("1,2");
		  chai.expect(output).to.include("3");
		  chai.expect(output).to.include("1,3");
		  chai.expect(output).to.include("2,3");
		  chai.expect(output).to.include("1,2,3");
		});
		it('Test Case #2', function () {
		  const output = program.powerset([]).map(sortAndStringify);
		  chai.expect(output.length === 1).to.be.true;
		  chai.expect(output).to.include("");
		});
		it('Test Case #3', function () {
		  const output = program.powerset([1]).map(sortAndStringify);
		  chai.expect(output.length === 2).to.be.true;
		  chai.expect(output).to.include("");
		  chai.expect(output).to.include("1");
		});
		it('Test Case #4', function () {
		  const output = program.powerset([1,2]).map(sortAndStringify);
		  chai.expect(output.length === 4).to.be.true;
		  chai.expect(output).to.include("");
		  chai.expect(output).to.include("1");
		  chai.expect(output).to.include("2");
		  chai.expect(output).to.include("1,2");
		});
		it('Test Case #5', function () {
		  const output = program.powerset([1,2,3,4]).map(sortAndStringify);
		  chai.expect(output.length === 16).to.be.true;
		  chai.expect(output).to.include("");
		  chai.expect(output).to.include("1");
		  chai.expect(output).to.include("2");
		  chai.expect(output).to.include("1,2");
		  chai.expect(output).to.include("3");
		  chai.expect(output).to.include("1,3");
		  chai.expect(output).to.include("2,3");
		  chai.expect(output).to.include("1,2,3");
		  chai.expect(output).to.include("4");
		  chai.expect(output).to.include("1,4");
		  chai.expect(output).to.include("2,4");
		  chai.expect(output).to.include("1,2,4");
		  chai.expect(output).to.include("3,4");
		  chai.expect(output).to.include("1,3,4");
		  chai.expect(output).to.include("2,3,4");
		  chai.expect(output).to.include("1,2,3,4");
		});
		it('Test Case #6', function () {
		  const output = program.powerset([1,2,3,4,5]).map(sortAndStringify);
		  chai.expect(output.length === 32).to.be.true;
		  chai.expect(output).to.include("");
		  chai.expect(output).to.include("1");
		  chai.expect(output).to.include("2");
		  chai.expect(output).to.include("1,2");
		  chai.expect(output).to.include("3");
		  chai.expect(output).to.include("1,3");
		  chai.expect(output).to.include("2,3");
		  chai.expect(output).to.include("1,2,3");
		  chai.expect(output).to.include("4");
		  chai.expect(output).to.include("1,4");
		  chai.expect(output).to.include("2,4");
		  chai.expect(output).to.include("1,2,4");
		  chai.expect(output).to.include("3,4");
		  chai.expect(output).to.include("1,3,4");
		  chai.expect(output).to.include("2,3,4");
		  chai.expect(output).to.include("1,2,3,4");
		  chai.expect(output).to.include("5");
		  chai.expect(output).to.include("1,5");
		  chai.expect(output).to.include("2,5");
		  chai.expect(output).to.include("1,2,5");
		  chai.expect(output).to.include("3,5");
		  chai.expect(output).to.include("1,3,5");
		  chai.expect(output).to.include("2,3,5");
		  chai.expect(output).to.include("1,2,3,5");
		  chai.expect(output).to.include("4,5");
		  chai.expect(output).to.include("1,4,5");
		  chai.expect(output).to.include("2,4,5");
		  chai.expect(output).to.include("1,2,4,5");
		  chai.expect(output).to.include("3,4,5");
		  chai.expect(output).to.include("1,3,4,5");
		  chai.expect(output).to.include("2,3,4,5");
		  chai.expect(output).to.include("1,2,3,4,5");
		});
		it('Test Case #7', function () {
		  const output = program.powerset([1,2,3,4,5,6]).map(sortAndStringify);
		  chai.expect(output.length === 64).to.be.true;
		  chai.expect(output).to.include("");
		  chai.expect(output).to.include("1");
		  chai.expect(output).to.include("2");
		  chai.expect(output).to.include("1,2");
		  chai.expect(output).to.include("3");
		  chai.expect(output).to.include("1,3");
		  chai.expect(output).to.include("2,3");
		  chai.expect(output).to.include("1,2,3");
		  chai.expect(output).to.include("4");
		  chai.expect(output).to.include("1,4");
		  chai.expect(output).to.include("2,4");
		  chai.expect(output).to.include("1,2,4");
		  chai.expect(output).to.include("3,4");
		  chai.expect(output).to.include("1,3,4");
		  chai.expect(output).to.include("2,3,4");
		  chai.expect(output).to.include("1,2,3,4");
		  chai.expect(output).to.include("5");
		  chai.expect(output).to.include("1,5");
		  chai.expect(output).to.include("2,5");
		  chai.expect(output).to.include("1,2,5");
		  chai.expect(output).to.include("3,5");
		  chai.expect(output).to.include("1,3,5");
		  chai.expect(output).to.include("2,3,5");
		  chai.expect(output).to.include("1,2,3,5");
		  chai.expect(output).to.include("4,5");
		  chai.expect(output).to.include("1,4,5");
		  chai.expect(output).to.include("2,4,5");
		  chai.expect(output).to.include("1,2,4,5");
		  chai.expect(output).to.include("3,4,5");
		  chai.expect(output).to.include("1,3,4,5");
		  chai.expect(output).to.include("2,3,4,5");
		  chai.expect(output).to.include("1,2,3,4,5");
		  chai.expect(output).to.include("6");
		  chai.expect(output).to.include("1,6");
		  chai.expect(output).to.include("2,6");
		  chai.expect(output).to.include("1,2,6");
		  chai.expect(output).to.include("3,6");
		  chai.expect(output).to.include("1,3,6");
		  chai.expect(output).to.include("2,3,6");
		  chai.expect(output).to.include("1,2,3,6");
		  chai.expect(output).to.include("4,6");
		  chai.expect(output).to.include("1,4,6");
		  chai.expect(output).to.include("2,4,6");
		  chai.expect(output).to.include("1,2,4,6");
		  chai.expect(output).to.include("3,4,6");
		  chai.expect(output).to.include("1,3,4,6");
		  chai.expect(output).to.include("2,3,4,6");
		  chai.expect(output).to.include("1,2,3,4,6");
		  chai.expect(output).to.include("5,6");
		  chai.expect(output).to.include("1,5,6");
		  chai.expect(output).to.include("2,5,6");
		  chai.expect(output).to.include("1,2,5,6");
		  chai.expect(output).to.include("3,5,6");
		  chai.expect(output).to.include("1,3,5,6");
		  chai.expect(output).to.include("2,3,5,6");
		  chai.expect(output).to.include("1,2,3,5,6");
		  chai.expect(output).to.include("4,5,6");
		  chai.expect(output).to.include("1,4,5,6");
		  chai.expect(output).to.include("2,4,5,6");
		  chai.expect(output).to.include("1,2,4,5,6");
		  chai.expect(output).to.include("3,4,5,6");
		  chai.expect(output).to.include("1,3,4,5,6");
		  chai.expect(output).to.include("2,3,4,5,6");
		  chai.expect(output).to.include("1,2,3,4,5,6");
		});
		""",
		
		"Min Max Stack Construction": """
		const program = require('./program');
		const chai = require('chai');
		function testMinMaxPeek(min, max, peek, stack) {
		  chai.expect(stack.getMin()).to.deep.equal(min);
		  chai.expect(stack.getMax()).to.deep.equal(max);
		  chai.expect(stack.peek()).to.deep.equal(peek);
		}
		it('Test Case #1', function () {
		  const stack = new program.MinMaxStack();
		  stack.push(5);
		  testMinMaxPeek(5, 5, 5, stack);
		  stack.push(7);
		  testMinMaxPeek(5, 7, 7, stack);
		  stack.push(2);
		  testMinMaxPeek(2, 7, 2, stack);
		  chai.expect(stack.pop()).to.deep.equal(2);
		  chai.expect(stack.pop()).to.deep.equal(7);
		  testMinMaxPeek(5, 5, 5, stack);
		});
		it('Test Case #2', function () {
		  const stack = new program.MinMaxStack();
		  stack.push(2);
		  testMinMaxPeek(2, 2, 2, stack);
		  stack.push(7);
		  testMinMaxPeek(2, 7, 7, stack);
		  stack.push(1);
		  testMinMaxPeek(1, 7, 1, stack);
		  stack.push(8);
		  testMinMaxPeek(1, 8, 8, stack);
		  stack.push(3);
		  testMinMaxPeek(1, 8, 3, stack);
		  stack.push(9);
		  testMinMaxPeek(1, 9, 9, stack);
		  chai.expect(stack.pop()).to.deep.equal(9);
		  testMinMaxPeek(1, 8, 3, stack);
		  chai.expect(stack.pop()).to.deep.equal(3);
		  testMinMaxPeek(1, 8, 8, stack);
		  chai.expect(stack.pop()).to.deep.equal(8);
		  testMinMaxPeek(1, 7, 1, stack);
		  chai.expect(stack.pop()).to.deep.equal(1);
		  testMinMaxPeek(2, 7, 7, stack);
		  chai.expect(stack.pop()).to.deep.equal(7);
		  testMinMaxPeek(2, 2, 2, stack);
		  chai.expect(stack.pop()).to.deep.equal(2);
		});
		it('Test Case #3', function () {
		  const stack = new program.MinMaxStack();
		  stack.push(5);
		  testMinMaxPeek(5, 5, 5, stack);
		  stack.push(5);
		  testMinMaxPeek(5, 5, 5, stack);
		  stack.push(5);
		  testMinMaxPeek(5, 5, 5, stack);
		  stack.push(5);
		  testMinMaxPeek(5, 5, 5, stack);
		  stack.push(8);
		  testMinMaxPeek(5, 8, 8, stack);
		  stack.push(8);
		  testMinMaxPeek(5, 8, 8, stack);
		  stack.push(0);
		  testMinMaxPeek(0, 8, 0, stack);
		  stack.push(8);
		  testMinMaxPeek(0, 8, 8, stack);
		  stack.push(9);
		  testMinMaxPeek(0, 9, 9, stack);
		  stack.push(5);
		  testMinMaxPeek(0, 9, 5, stack);
		  chai.expect(stack.pop()).to.deep.equal(5);
		  testMinMaxPeek(0, 9, 9, stack);
		  chai.expect(stack.pop()).to.deep.equal(9);
		  testMinMaxPeek(0, 8, 8, stack);
		  chai.expect(stack.pop()).to.deep.equal(8);
		  testMinMaxPeek(0, 8, 0, stack);
		  chai.expect(stack.pop()).to.deep.equal(0);
		  testMinMaxPeek(5, 8, 8, stack);
		  chai.expect(stack.pop()).to.deep.equal(8);
		  testMinMaxPeek(5, 8, 8, stack);
		  chai.expect(stack.pop()).to.deep.equal(8);
		  testMinMaxPeek(5, 5, 5, stack);
		  chai.expect(stack.pop()).to.deep.equal(5);
		  testMinMaxPeek(5, 5, 5, stack);
		  chai.expect(stack.pop()).to.deep.equal(5);
		  testMinMaxPeek(5, 5, 5, stack);
		  chai.expect(stack.pop()).to.deep.equal(5);
		  testMinMaxPeek(5, 5, 5, stack);
		  chai.expect(stack.pop()).to.deep.equal(5);
		});
		it('Test Case #4', function () {
		  const stack = new program.MinMaxStack();
		  stack.push(2);
		  testMinMaxPeek(2, 2, 2, stack);
		  stack.push(0);
		  testMinMaxPeek(0, 2, 0, stack);
		  stack.push(5);
		  testMinMaxPeek(0, 5, 5, stack);
		  stack.push(4);
		  testMinMaxPeek(0, 5, 4, stack);
		  chai.expect(stack.pop()).to.deep.equal(4);
		  testMinMaxPeek(0, 5, 5, stack);
		  chai.expect(stack.pop()).to.deep.equal(5);
		  testMinMaxPeek(0, 2, 0, stack);
		  stack.push(4);
		  testMinMaxPeek(0, 4, 4, stack);
		  stack.push(11);
		  testMinMaxPeek(0, 11, 11, stack);
		  stack.push(-11);
		  testMinMaxPeek(-11, 11, -11, stack);
		  chai.expect(stack.pop()).to.deep.equal(-11);
		  testMinMaxPeek(0, 11, 11, stack);
		  chai.expect(stack.pop()).to.deep.equal(11);
		  testMinMaxPeek(0, 4, 4, stack);
		  chai.expect(stack.pop()).to.deep.equal(4);
		  testMinMaxPeek(0, 2, 0, stack);
		  chai.expect(stack.pop()).to.deep.equal(0);
		  testMinMaxPeek(2, 2, 2, stack);
		  chai.expect(stack.pop()).to.deep.equal(2);
		  stack.push(6);
		  testMinMaxPeek(6, 6, 6, stack);
		  chai.expect(stack.pop()).to.deep.equal(6);
		});
		""",
		
		"Min Height BST": """
		const program = require('./program');
		const chai = require('chai');
		function validateBst(tree) {
		  return validateBstHelper(tree, -Infinity, Infinity);
		}
		function validateBstHelper(tree, minValue, maxValue) {
		  if (tree === null) return true;
		  if (tree.value < minValue || tree.value >= maxValue) return false;
		  const leftIsValid = validateBstHelper(tree.left, minValue, tree.value);
		  return leftIsValid && validateBstHelper(tree.right, tree.value, maxValue);
		}
		function inOrderTraverse(tree, array) {
		  if (tree !== null) {
			inOrderTraverse(tree.left, array);
			array.push(tree.value);
			inOrderTraverse(tree.right, array);
		  }
		  return array;
		}
		function getTreeHeight(tree, height = 0) {
		  if (tree === null) return height;
		  const leftTreeHeight = getTreeHeight(tree.left, height + 1);
		  const rightTreeHeight = getTreeHeight(tree.right, height + 1);
		  return Math.max(leftTreeHeight, rightTreeHeight);
		}
		it('Test Case #1', function () {
		  const array = [1,2,5,7,10,13,14,15,22];
		  const tree = program.minHeightBst(array);
		  chai.expect(validateBst(tree)).to.deep.equal(true);
		  chai.expect(getTreeHeight(tree)).to.deep.equal(4);
		  const inOrder = inOrderTraverse(tree, []);
		  const expected = [1, 2, 5, 7, 10, 13, 14, 15, 22];
		  chai.expect(inOrder).to.deep.equal(expected);
		});
		it('Test Case #2', function () {
		  const array = [1];
		  const tree = program.minHeightBst(array);
		  chai.expect(validateBst(tree)).to.deep.equal(true);
		  chai.expect(getTreeHeight(tree)).to.deep.equal(1);
		  const inOrder = inOrderTraverse(tree, []);
		  const expected = [1];
		  chai.expect(inOrder).to.deep.equal(expected);
		});
		it('Test Case #3', function () {
		  const array = [1,2];
		  const tree = program.minHeightBst(array);
		  chai.expect(validateBst(tree)).to.deep.equal(true);
		  chai.expect(getTreeHeight(tree)).to.deep.equal(2);
		  const inOrder = inOrderTraverse(tree, []);
		  const expected = [1,2];
		  chai.expect(inOrder).to.deep.equal(expected);
		});
		it('Test Case #4', function () {
		  const array = [1,2,5];
		  const tree = program.minHeightBst(array);
		  chai.expect(validateBst(tree)).to.deep.equal(true);
		  chai.expect(getTreeHeight(tree)).to.deep.equal(2);
		  const inOrder = inOrderTraverse(tree, []);
		  const expected = [1, 2, 5];
		  chai.expect(inOrder).to.deep.equal(expected);
		});
		it('Test Case #5', function () {
		  const array = [1,2,5,7];
		  const tree = program.minHeightBst(array);
		  chai.expect(validateBst(tree)).to.deep.equal(true);
		  chai.expect(getTreeHeight(tree)).to.deep.equal(3);
		  const inOrder = inOrderTraverse(tree, []);
		  const expected = [1, 2, 5, 7];
		  chai.expect(inOrder).to.deep.equal(expected);
		});
		it('Test Case #6', function () {
		  const array = [1,2,5,7,10];
		  const tree = program.minHeightBst(array);
		  chai.expect(validateBst(tree)).to.deep.equal(true);
		  chai.expect(getTreeHeight(tree)).to.deep.equal(3);
		  const inOrder = inOrderTraverse(tree, []);
		  const expected = [1, 2, 5, 7, 10];
		  chai.expect(inOrder).to.deep.equal(expected);
		});
		it('Test Case #7', function () {
		  const array = [1,2,5,7,10,13];
		  const tree = program.minHeightBst(array);
		  chai.expect(validateBst(tree)).to.deep.equal(true);
		  chai.expect(getTreeHeight(tree)).to.deep.equal(3);
		  const inOrder = inOrderTraverse(tree, []);
		  const expected = [1, 2, 5, 7, 10, 13];
		  chai.expect(inOrder).to.deep.equal(expected);
		});
		it('Test Case #8', function () {
		  const array = [1,2,5,7,10,13,14];
		  const tree = program.minHeightBst(array);
		  chai.expect(validateBst(tree)).to.deep.equal(true);
		  chai.expect(getTreeHeight(tree)).to.deep.equal(3);
		  const inOrder = inOrderTraverse(tree, []);
		  const expected = [1, 2, 5, 7, 10, 13, 14];
		  chai.expect(inOrder).to.deep.equal(expected);
		});
		it('Test Case #9', function () {
		  const array = [1,2,5,7,10,13,14,15];
		  const tree = program.minHeightBst(array);
		  chai.expect(validateBst(tree)).to.deep.equal(true);
		  chai.expect(getTreeHeight(tree)).to.deep.equal(4);
		  const inOrder = inOrderTraverse(tree, []);
		  const expected = [1, 2, 5, 7, 10, 13, 14, 15];
		  chai.expect(inOrder).to.deep.equal(expected);
		});
		it('Test Case #10', function () {
		  const array = [1,2,5,7,10,13,14,15,22];
		  const tree = program.minHeightBst(array);
		  chai.expect(validateBst(tree)).to.deep.equal(true);
		  chai.expect(getTreeHeight(tree)).to.deep.equal(4);
		  const inOrder = inOrderTraverse(tree, []);
		  const expected = [1, 2, 5, 7, 10, 13, 14, 15, 22];
		  chai.expect(inOrder).to.deep.equal(expected);
		});
		it('Test Case #11', function () {
		  const array = [1,2,5,7,10,13,14,15,22,28];
		  const tree = program.minHeightBst(array);
		  chai.expect(validateBst(tree)).to.deep.equal(true);
		  chai.expect(getTreeHeight(tree)).to.deep.equal(4);
		  const inOrder = inOrderTraverse(tree, []);
		  const expected = [1, 2, 5, 7, 10, 13, 14, 15, 22, 28];
		  chai.expect(inOrder).to.deep.equal(expected);
		});
		it('Test Case #12', function () {
		  const array = [1,2,5,7,10,13,14,15,22,28,32];
		  const tree = program.minHeightBst(array);
		  chai.expect(validateBst(tree)).to.deep.equal(true);
		  chai.expect(getTreeHeight(tree)).to.deep.equal(4);
		  const inOrder = inOrderTraverse(tree, []);
		  const expected = [1, 2, 5, 7, 10, 13, 14, 15, 22, 28, 32];
		  chai.expect(inOrder).to.deep.equal(expected);
		});
		it('Test Case #13', function () {
		  const array = [1,2,5,7,10,13,14,15,22,28,32,36];
		  const tree = program.minHeightBst(array);
		  chai.expect(validateBst(tree)).to.deep.equal(true);
		  chai.expect(getTreeHeight(tree)).to.deep.equal(4);
		  const inOrder = inOrderTraverse(tree, []);
		  const expected = [1, 2, 5, 7, 10, 13, 14, 15, 22, 28, 32, 36];
		  chai.expect(inOrder).to.deep.equal(expected);
		});
		it('Test Case #14', function () {
		  const array = [1,2,5,7,10,13,14,15,22,28,32,36,89];
		  const tree = program.minHeightBst(array);
		  chai.expect(validateBst(tree)).to.deep.equal(true);
		  chai.expect(getTreeHeight(tree)).to.deep.equal(4);
		  const inOrder = inOrderTraverse(tree, []);
		  const expected = [1, 2, 5, 7, 10, 13, 14, 15, 22, 28, 32, 36, 89];
		  chai.expect(inOrder).to.deep.equal(expected);
		});
		it('Test Case #15', function () {
		  const array = [1,2,5,7,10,13,14,15,22,28,32,36,89,92];
		  const tree = program.minHeightBst(array);
		  chai.expect(validateBst(tree)).to.deep.equal(true);
		  chai.expect(getTreeHeight(tree)).to.deep.equal(4);
		  const inOrder = inOrderTraverse(tree, []);
		  const expected = [1, 2, 5, 7, 10, 13, 14, 15, 22, 28, 32, 36, 89, 92];
		  chai.expect(inOrder).to.deep.equal(expected);
		});
		it('Test Case #16', function () {
		  const array = [1,2,5,7,10,13,14,15,22,28,32,36,89,92,9000];
		  const tree = program.minHeightBst(array);
		  chai.expect(validateBst(tree)).to.deep.equal(true);
		  chai.expect(getTreeHeight(tree)).to.deep.equal(4);
		  const inOrder = inOrderTraverse(tree, []);
		  const expected = [1, 2, 5, 7, 10, 13, 14, 15, 22, 28, 32, 36, 89, 92, 9000];
		  chai.expect(inOrder).to.deep.equal(expected);
		});
		it('Test Case #17', function () {
		  const array = [1,2,5,7,10,13,14,15,22,28,32,36,89,92,9000,9001];
		  const tree = program.minHeightBst(array);
		  chai.expect(validateBst(tree)).to.deep.equal(true);
		  chai.expect(getTreeHeight(tree)).to.deep.equal(5);
		  const inOrder = inOrderTraverse(tree, []);
		  const expected = [1, 2, 5, 7, 10, 13, 14, 15, 22, 28, 32, 36, 89, 92, 9000, 9001];
		  chai.expect(inOrder).to.deep.equal(expected);
		});
		""",
		
		"LRU Cache": """
		const program = require('./program');
		const chai = require('chai');
		it('Test Case #1', function () {
		  const lruCache = new program.LRUCache(3);
		  lruCache.insertKeyValuePair("b", 2);
		  lruCache.insertKeyValuePair("a", 1);
		  lruCache.insertKeyValuePair("c", 3);
		  chai.expect(lruCache.getMostRecentKey()).to.deep.equal("c");
		  chai.expect(lruCache.getValueFromKey("a")).to.deep.equal(1);
		  chai.expect(lruCache.getMostRecentKey()).to.deep.equal("a");
		  lruCache.insertKeyValuePair("d", 4);
		  chai.expect(lruCache.getValueFromKey("b")).to.deep.equal(null);
		  lruCache.insertKeyValuePair("a", 5);
		  chai.expect(lruCache.getValueFromKey("a")).to.deep.equal(5);
		});
		it('Test Case #2', function () {
		  const lruCache = new program.LRUCache(1);
		  chai.expect(lruCache.getValueFromKey("a")).to.deep.equal(null);
		  lruCache.insertKeyValuePair("a", 1);
		  chai.expect(lruCache.getValueFromKey("a")).to.deep.equal(1);
		  lruCache.insertKeyValuePair("a", 9001);
		  chai.expect(lruCache.getValueFromKey("a")).to.deep.equal(9001);
		  lruCache.insertKeyValuePair("b", 2);
		  chai.expect(lruCache.getValueFromKey("a")).to.deep.equal(null);
		  chai.expect(lruCache.getValueFromKey("b")).to.deep.equal(2);
		  lruCache.insertKeyValuePair("c", 3);
		  chai.expect(lruCache.getValueFromKey("a")).to.deep.equal(null);
		  chai.expect(lruCache.getValueFromKey("b")).to.deep.equal(null);
		  chai.expect(lruCache.getValueFromKey("c")).to.deep.equal(3);
		});
		it('Test Case #3', function () {
		  const lruCache = new program.LRUCache(4);
		  lruCache.insertKeyValuePair("a", 1);
		  lruCache.insertKeyValuePair("b", 2);
		  lruCache.insertKeyValuePair("c", 3);
		  lruCache.insertKeyValuePair("d", 4);
		  chai.expect(lruCache.getValueFromKey("a")).to.deep.equal(1);
		  chai.expect(lruCache.getValueFromKey("b")).to.deep.equal(2);
		  chai.expect(lruCache.getValueFromKey("c")).to.deep.equal(3);
		  chai.expect(lruCache.getValueFromKey("d")).to.deep.equal(4);
		  lruCache.insertKeyValuePair("e", 5);
		  chai.expect(lruCache.getValueFromKey("a")).to.deep.equal(null);
		  chai.expect(lruCache.getValueFromKey("b")).to.deep.equal(2);
		  chai.expect(lruCache.getValueFromKey("c")).to.deep.equal(3);
		  chai.expect(lruCache.getValueFromKey("d")).to.deep.equal(4);
		  chai.expect(lruCache.getValueFromKey("e")).to.deep.equal(5);
		});
		it('Test Case #4', function () {
		  const lruCache = new program.LRUCache(4);
		  lruCache.insertKeyValuePair("a", 1);
		  chai.expect(lruCache.getMostRecentKey()).to.deep.equal("a");
		  lruCache.insertKeyValuePair("b", 2);
		  chai.expect(lruCache.getMostRecentKey()).to.deep.equal("b");
		  lruCache.insertKeyValuePair("c", 3);
		  chai.expect(lruCache.getMostRecentKey()).to.deep.equal("c");
		  lruCache.insertKeyValuePair("d", 4);
		  chai.expect(lruCache.getMostRecentKey()).to.deep.equal("d");
		  chai.expect(lruCache.getValueFromKey("a")).to.deep.equal(1);
		  chai.expect(lruCache.getMostRecentKey()).to.deep.equal("a");
		  chai.expect(lruCache.getValueFromKey("b")).to.deep.equal(2);
		  chai.expect(lruCache.getMostRecentKey()).to.deep.equal("b");
		  chai.expect(lruCache.getValueFromKey("c")).to.deep.equal(3);
		  chai.expect(lruCache.getMostRecentKey()).to.deep.equal("c");
		  chai.expect(lruCache.getValueFromKey("d")).to.deep.equal(4);
		  chai.expect(lruCache.getMostRecentKey()).to.deep.equal("d");
		  lruCache.insertKeyValuePair("e", 5);
		  chai.expect(lruCache.getMostRecentKey()).to.deep.equal("e");
		});
		it('Test Case #5', function () {
		  const lruCache = new program.LRUCache(4);
		  lruCache.insertKeyValuePair("a", 1);
		  lruCache.insertKeyValuePair("b", 2);
		  lruCache.insertKeyValuePair("c", 3);
		  lruCache.insertKeyValuePair("d", 4);
		  chai.expect(lruCache.getValueFromKey("a")).to.deep.equal(1);
		  lruCache.insertKeyValuePair("e", 5);
		  chai.expect(lruCache.getValueFromKey("a")).to.deep.equal(1);
		  chai.expect(lruCache.getValueFromKey("b")).to.deep.equal(null);
		  chai.expect(lruCache.getValueFromKey("c")).to.deep.equal(3);
		  lruCache.insertKeyValuePair("f", 5);
		  chai.expect(lruCache.getValueFromKey("c")).to.deep.equal(3);
		  chai.expect(lruCache.getValueFromKey("d")).to.deep.equal(null);
		  lruCache.insertKeyValuePair("g", 5);
		  chai.expect(lruCache.getValueFromKey("e")).to.deep.equal(null);
		  chai.expect(lruCache.getValueFromKey("a")).to.deep.equal(1);
		  chai.expect(lruCache.getValueFromKey("c")).to.deep.equal(3);
		  chai.expect(lruCache.getValueFromKey("f")).to.deep.equal(5);
		  chai.expect(lruCache.getValueFromKey("g")).to.deep.equal(5);
		});
		""",
		
		"Lowest Common Manager": """
		const program = require('./program');
		const chai = require('chai');
		class OrgChart {
		  constructor(name) {
			this.name = name;
			this.directReports = [];
		  }
		  addDirectReports(directReports) {
			for (const directReport of directReports) {
			  this.directReports.push(directReport);
			}
		  }
		}
		function getOrgCharts() {
		  const orgCharts = {};
		  const ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('');
		  for (const letter of ALPHABET) {
			orgCharts[letter] = new OrgChart(letter);
		  }
		  return orgCharts;
		}
		it('Test Case #1', function () {
		  const orgCharts = getOrgCharts();
		  orgCharts["A"].addDirectReports([orgCharts["B"], orgCharts["C"]]);
		  orgCharts["B"].addDirectReports([orgCharts["D"], orgCharts["E"]]);
		  orgCharts["C"].addDirectReports([orgCharts["F"], orgCharts["G"]]);
		  orgCharts["D"].addDirectReports([orgCharts["H"], orgCharts["I"]]);
		  const lcm = program.getLowestCommonManager(orgCharts.A, orgCharts.E, orgCharts.I);
		  chai.expect(lcm).to.deep.equal(orgCharts.B);
		});
		it('Test Case #2', function () {
		  const orgCharts = getOrgCharts();
		  orgCharts["A"].addDirectReports([orgCharts["B"], orgCharts["C"], orgCharts["D"], orgCharts["E"], orgCharts["F"]]);
		  orgCharts["B"].addDirectReports([orgCharts["G"], orgCharts["H"], orgCharts["I"]]);
		  orgCharts["C"].addDirectReports([orgCharts["J"]]);
		  orgCharts["D"].addDirectReports([orgCharts["K"], orgCharts["L"]]);
		  orgCharts["F"].addDirectReports([orgCharts["M"], orgCharts["N"]]);
		  orgCharts["H"].addDirectReports([orgCharts["O"], orgCharts["P"], orgCharts["Q"], orgCharts["R"]]);
		  orgCharts["K"].addDirectReports([orgCharts["S"]]);
		  orgCharts["P"].addDirectReports([orgCharts["T"], orgCharts["U"]]);
		  orgCharts["R"].addDirectReports([orgCharts["V"]]);
		  orgCharts["V"].addDirectReports([orgCharts["W"], orgCharts["X"], orgCharts["Y"]]);
		  orgCharts["X"].addDirectReports([orgCharts["Z"]]);
		  const lcm = program.getLowestCommonManager(orgCharts.A, orgCharts.A, orgCharts.B);
		  chai.expect(lcm).to.deep.equal(orgCharts.A);
		});
		it('Test Case #3', function () {
		  const orgCharts = getOrgCharts();
		  orgCharts["A"].addDirectReports([orgCharts["B"], orgCharts["C"], orgCharts["D"], orgCharts["E"], orgCharts["F"]]);
		  orgCharts["B"].addDirectReports([orgCharts["G"], orgCharts["H"], orgCharts["I"]]);
		  orgCharts["C"].addDirectReports([orgCharts["J"]]);
		  orgCharts["D"].addDirectReports([orgCharts["K"], orgCharts["L"]]);
		  orgCharts["F"].addDirectReports([orgCharts["M"], orgCharts["N"]]);
		  orgCharts["H"].addDirectReports([orgCharts["O"], orgCharts["P"], orgCharts["Q"], orgCharts["R"]]);
		  orgCharts["K"].addDirectReports([orgCharts["S"]]);
		  orgCharts["P"].addDirectReports([orgCharts["T"], orgCharts["U"]]);
		  orgCharts["R"].addDirectReports([orgCharts["V"]]);
		  orgCharts["V"].addDirectReports([orgCharts["W"], orgCharts["X"], orgCharts["Y"]]);
		  orgCharts["X"].addDirectReports([orgCharts["Z"]]);
		  const lcm = program.getLowestCommonManager(orgCharts.A, orgCharts.B, orgCharts.F);
		  chai.expect(lcm).to.deep.equal(orgCharts.A);
		});
		it('Test Case #4', function () {
		  const orgCharts = getOrgCharts();
		  orgCharts["A"].addDirectReports([orgCharts["B"], orgCharts["C"], orgCharts["D"], orgCharts["E"], orgCharts["F"]]);
		  orgCharts["B"].addDirectReports([orgCharts["G"], orgCharts["H"], orgCharts["I"]]);
		  orgCharts["C"].addDirectReports([orgCharts["J"]]);
		  orgCharts["D"].addDirectReports([orgCharts["K"], orgCharts["L"]]);
		  orgCharts["F"].addDirectReports([orgCharts["M"], orgCharts["N"]]);
		  orgCharts["H"].addDirectReports([orgCharts["O"], orgCharts["P"], orgCharts["Q"], orgCharts["R"]]);
		  orgCharts["K"].addDirectReports([orgCharts["S"]]);
		  orgCharts["P"].addDirectReports([orgCharts["T"], orgCharts["U"]]);
		  orgCharts["R"].addDirectReports([orgCharts["V"]]);
		  orgCharts["V"].addDirectReports([orgCharts["W"], orgCharts["X"], orgCharts["Y"]]);
		  orgCharts["X"].addDirectReports([orgCharts["Z"]]);
		  const lcm = program.getLowestCommonManager(orgCharts.A, orgCharts.G, orgCharts.M);
		  chai.expect(lcm).to.deep.equal(orgCharts.A);
		});
		it('Test Case #5', function () {
		  const orgCharts = getOrgCharts();
		  orgCharts["A"].addDirectReports([orgCharts["B"], orgCharts["C"], orgCharts["D"], orgCharts["E"], orgCharts["F"]]);
		  orgCharts["B"].addDirectReports([orgCharts["G"], orgCharts["H"], orgCharts["I"]]);
		  orgCharts["C"].addDirectReports([orgCharts["J"]]);
		  orgCharts["D"].addDirectReports([orgCharts["K"], orgCharts["L"]]);
		  orgCharts["F"].addDirectReports([orgCharts["M"], orgCharts["N"]]);
		  orgCharts["H"].addDirectReports([orgCharts["O"], orgCharts["P"], orgCharts["Q"], orgCharts["R"]]);
		  orgCharts["K"].addDirectReports([orgCharts["S"]]);
		  orgCharts["P"].addDirectReports([orgCharts["T"], orgCharts["U"]]);
		  orgCharts["R"].addDirectReports([orgCharts["V"]]);
		  orgCharts["V"].addDirectReports([orgCharts["W"], orgCharts["X"], orgCharts["Y"]]);
		  orgCharts["X"].addDirectReports([orgCharts["Z"]]);
		  const lcm = program.getLowestCommonManager(orgCharts.A, orgCharts.U, orgCharts.S);
		  chai.expect(lcm).to.deep.equal(orgCharts.A);
		});
		it('Test Case #6', function () {
		  const orgCharts = getOrgCharts();
		  orgCharts["A"].addDirectReports([orgCharts["B"], orgCharts["C"], orgCharts["D"], orgCharts["E"], orgCharts["F"]]);
		  orgCharts["B"].addDirectReports([orgCharts["G"], orgCharts["H"], orgCharts["I"]]);
		  orgCharts["C"].addDirectReports([orgCharts["J"]]);
		  orgCharts["D"].addDirectReports([orgCharts["K"], orgCharts["L"]]);
		  orgCharts["F"].addDirectReports([orgCharts["M"], orgCharts["N"]]);
		  orgCharts["H"].addDirectReports([orgCharts["O"], orgCharts["P"], orgCharts["Q"], orgCharts["R"]]);
		  orgCharts["K"].addDirectReports([orgCharts["S"]]);
		  orgCharts["P"].addDirectReports([orgCharts["T"], orgCharts["U"]]);
		  orgCharts["R"].addDirectReports([orgCharts["V"]]);
		  orgCharts["V"].addDirectReports([orgCharts["W"], orgCharts["X"], orgCharts["Y"]]);
		  orgCharts["X"].addDirectReports([orgCharts["Z"]]);
		  const lcm = program.getLowestCommonManager(orgCharts.A, orgCharts.Z, orgCharts.M);
		  chai.expect(lcm).to.deep.equal(orgCharts.A);
		});
		it('Test Case #7', function () {
		  const orgCharts = getOrgCharts();
		  orgCharts["A"].addDirectReports([orgCharts["B"], orgCharts["C"], orgCharts["D"], orgCharts["E"], orgCharts["F"]]);
		  orgCharts["B"].addDirectReports([orgCharts["G"], orgCharts["H"], orgCharts["I"]]);
		  orgCharts["C"].addDirectReports([orgCharts["J"]]);
		  orgCharts["D"].addDirectReports([orgCharts["K"], orgCharts["L"]]);
		  orgCharts["F"].addDirectReports([orgCharts["M"], orgCharts["N"]]);
		  orgCharts["H"].addDirectReports([orgCharts["O"], orgCharts["P"], orgCharts["Q"], orgCharts["R"]]);
		  orgCharts["K"].addDirectReports([orgCharts["S"]]);
		  orgCharts["P"].addDirectReports([orgCharts["T"], orgCharts["U"]]);
		  orgCharts["R"].addDirectReports([orgCharts["V"]]);
		  orgCharts["V"].addDirectReports([orgCharts["W"], orgCharts["X"], orgCharts["Y"]]);
		  orgCharts["X"].addDirectReports([orgCharts["Z"]]);
		  const lcm = program.getLowestCommonManager(orgCharts.A, orgCharts.O, orgCharts.I);
		  chai.expect(lcm).to.deep.equal(orgCharts.B);
		});
		it('Test Case #8', function () {
		  const orgCharts = getOrgCharts();
		  orgCharts["A"].addDirectReports([orgCharts["B"], orgCharts["C"], orgCharts["D"], orgCharts["E"], orgCharts["F"]]);
		  orgCharts["B"].addDirectReports([orgCharts["G"], orgCharts["H"], orgCharts["I"]]);
		  orgCharts["C"].addDirectReports([orgCharts["J"]]);
		  orgCharts["D"].addDirectReports([orgCharts["K"], orgCharts["L"]]);
		  orgCharts["F"].addDirectReports([orgCharts["M"], orgCharts["N"]]);
		  orgCharts["H"].addDirectReports([orgCharts["O"], orgCharts["P"], orgCharts["Q"], orgCharts["R"]]);
		  orgCharts["K"].addDirectReports([orgCharts["S"]]);
		  orgCharts["P"].addDirectReports([orgCharts["T"], orgCharts["U"]]);
		  orgCharts["R"].addDirectReports([orgCharts["V"]]);
		  orgCharts["V"].addDirectReports([orgCharts["W"], orgCharts["X"], orgCharts["Y"]]);
		  orgCharts["X"].addDirectReports([orgCharts["Z"]]);
		  const lcm = program.getLowestCommonManager(orgCharts.A, orgCharts.T, orgCharts.Z);
		  chai.expect(lcm).to.deep.equal(orgCharts.H);
		});
		it('Test Case #9', function () {
		  const orgCharts = getOrgCharts();
		  orgCharts["A"].addDirectReports([orgCharts["B"], orgCharts["C"], orgCharts["D"], orgCharts["E"], orgCharts["F"]]);
		  orgCharts["B"].addDirectReports([orgCharts["G"], orgCharts["H"], orgCharts["I"]]);
		  orgCharts["C"].addDirectReports([orgCharts["J"]]);
		  orgCharts["D"].addDirectReports([orgCharts["K"], orgCharts["L"]]);
		  orgCharts["F"].addDirectReports([orgCharts["M"], orgCharts["N"]]);
		  orgCharts["H"].addDirectReports([orgCharts["O"], orgCharts["P"], orgCharts["Q"], orgCharts["R"]]);
		  orgCharts["K"].addDirectReports([orgCharts["S"]]);
		  orgCharts["P"].addDirectReports([orgCharts["T"], orgCharts["U"]]);
		  orgCharts["R"].addDirectReports([orgCharts["V"]]);
		  orgCharts["V"].addDirectReports([orgCharts["W"], orgCharts["X"], orgCharts["Y"]]);
		  orgCharts["X"].addDirectReports([orgCharts["Z"]]);
		  const lcm = program.getLowestCommonManager(orgCharts.A, orgCharts.T, orgCharts.V);
		  chai.expect(lcm).to.deep.equal(orgCharts.H);
		});
		it('Test Case #10', function () {
		  const orgCharts = getOrgCharts();
		  orgCharts["A"].addDirectReports([orgCharts["B"], orgCharts["C"], orgCharts["D"], orgCharts["E"], orgCharts["F"]]);
		  orgCharts["B"].addDirectReports([orgCharts["G"], orgCharts["H"], orgCharts["I"]]);
		  orgCharts["C"].addDirectReports([orgCharts["J"]]);
		  orgCharts["D"].addDirectReports([orgCharts["K"], orgCharts["L"]]);
		  orgCharts["F"].addDirectReports([orgCharts["M"], orgCharts["N"]]);
		  orgCharts["H"].addDirectReports([orgCharts["O"], orgCharts["P"], orgCharts["Q"], orgCharts["R"]]);
		  orgCharts["K"].addDirectReports([orgCharts["S"]]);
		  orgCharts["P"].addDirectReports([orgCharts["T"], orgCharts["U"]]);
		  orgCharts["R"].addDirectReports([orgCharts["V"]]);
		  orgCharts["V"].addDirectReports([orgCharts["W"], orgCharts["X"], orgCharts["Y"]]);
		  orgCharts["X"].addDirectReports([orgCharts["Z"]]);
		  const lcm = program.getLowestCommonManager(orgCharts.A, orgCharts.T, orgCharts.H);
		  chai.expect(lcm).to.deep.equal(orgCharts.H);
		});
		it('Test Case #11', function () {
		  const orgCharts = getOrgCharts();
		  orgCharts["A"].addDirectReports([orgCharts["B"], orgCharts["C"], orgCharts["D"], orgCharts["E"], orgCharts["F"]]);
		  orgCharts["B"].addDirectReports([orgCharts["G"], orgCharts["H"], orgCharts["I"]]);
		  orgCharts["C"].addDirectReports([orgCharts["J"]]);
		  orgCharts["D"].addDirectReports([orgCharts["K"], orgCharts["L"]]);
		  orgCharts["F"].addDirectReports([orgCharts["M"], orgCharts["N"]]);
		  orgCharts["H"].addDirectReports([orgCharts["O"], orgCharts["P"], orgCharts["Q"], orgCharts["R"]]);
		  orgCharts["K"].addDirectReports([orgCharts["S"]]);
		  orgCharts["P"].addDirectReports([orgCharts["T"], orgCharts["U"]]);
		  orgCharts["R"].addDirectReports([orgCharts["V"]]);
		  orgCharts["V"].addDirectReports([orgCharts["W"], orgCharts["X"], orgCharts["Y"]]);
		  orgCharts["X"].addDirectReports([orgCharts["Z"]]);
		  const lcm = program.getLowestCommonManager(orgCharts.A, orgCharts.W, orgCharts.V);
		  chai.expect(lcm).to.deep.equal(orgCharts.V);
		});
		it('Test Case #12', function () {
		  const orgCharts = getOrgCharts();
		  orgCharts["A"].addDirectReports([orgCharts["B"], orgCharts["C"], orgCharts["D"], orgCharts["E"], orgCharts["F"]]);
		  orgCharts["B"].addDirectReports([orgCharts["G"], orgCharts["H"], orgCharts["I"]]);
		  orgCharts["C"].addDirectReports([orgCharts["J"]]);
		  orgCharts["D"].addDirectReports([orgCharts["K"], orgCharts["L"]]);
		  orgCharts["F"].addDirectReports([orgCharts["M"], orgCharts["N"]]);
		  orgCharts["H"].addDirectReports([orgCharts["O"], orgCharts["P"], orgCharts["Q"], orgCharts["R"]]);
		  orgCharts["K"].addDirectReports([orgCharts["S"]]);
		  orgCharts["P"].addDirectReports([orgCharts["T"], orgCharts["U"]]);
		  orgCharts["R"].addDirectReports([orgCharts["V"]]);
		  orgCharts["V"].addDirectReports([orgCharts["W"], orgCharts["X"], orgCharts["Y"]]);
		  orgCharts["X"].addDirectReports([orgCharts["Z"]]);
		  const lcm = program.getLowestCommonManager(orgCharts.A, orgCharts.Z, orgCharts.B);
		  chai.expect(lcm).to.deep.equal(orgCharts.B);
		});
		it('Test Case #13', function () {
		  const orgCharts = getOrgCharts();
		  orgCharts["A"].addDirectReports([orgCharts["B"], orgCharts["C"], orgCharts["D"], orgCharts["E"], orgCharts["F"]]);
		  orgCharts["B"].addDirectReports([orgCharts["G"], orgCharts["H"], orgCharts["I"]]);
		  orgCharts["C"].addDirectReports([orgCharts["J"]]);
		  orgCharts["D"].addDirectReports([orgCharts["K"], orgCharts["L"]]);
		  orgCharts["F"].addDirectReports([orgCharts["M"], orgCharts["N"]]);
		  orgCharts["H"].addDirectReports([orgCharts["O"], orgCharts["P"], orgCharts["Q"], orgCharts["R"]]);
		  orgCharts["K"].addDirectReports([orgCharts["S"]]);
		  orgCharts["P"].addDirectReports([orgCharts["T"], orgCharts["U"]]);
		  orgCharts["R"].addDirectReports([orgCharts["V"]]);
		  orgCharts["V"].addDirectReports([orgCharts["W"], orgCharts["X"], orgCharts["Y"]]);
		  orgCharts["X"].addDirectReports([orgCharts["Z"]]);
		  const lcm = program.getLowestCommonManager(orgCharts.A, orgCharts.Q, orgCharts.W);
		  chai.expect(lcm).to.deep.equal(orgCharts.H);
		});
		it('Test Case #14', function () {
		  const orgCharts = getOrgCharts();
		  orgCharts["A"].addDirectReports([orgCharts["B"], orgCharts["C"], orgCharts["D"], orgCharts["E"], orgCharts["F"]]);
		  orgCharts["B"].addDirectReports([orgCharts["G"], orgCharts["H"], orgCharts["I"]]);
		  orgCharts["C"].addDirectReports([orgCharts["J"]]);
		  orgCharts["D"].addDirectReports([orgCharts["K"], orgCharts["L"]]);
		  orgCharts["F"].addDirectReports([orgCharts["M"], orgCharts["N"]]);
		  orgCharts["H"].addDirectReports([orgCharts["O"], orgCharts["P"], orgCharts["Q"], orgCharts["R"]]);
		  orgCharts["K"].addDirectReports([orgCharts["S"]]);
		  orgCharts["P"].addDirectReports([orgCharts["T"], orgCharts["U"]]);
		  orgCharts["R"].addDirectReports([orgCharts["V"]]);
		  orgCharts["V"].addDirectReports([orgCharts["W"], orgCharts["X"], orgCharts["Y"]]);
		  orgCharts["X"].addDirectReports([orgCharts["Z"]]);
		  const lcm = program.getLowestCommonManager(orgCharts.A, orgCharts.A, orgCharts.Z);
		  chai.expect(lcm).to.deep.equal(orgCharts.A);
		});
		""",
		
		"Linked List Construction": """
		
		""",
		
		"BST Construction": """
		"""
	]
}

//		let test = """
//		const program = require('./program');
//		const chai = require('chai');
//
//		it('Test Case #1', function () {
//		  const output = program.twoNumberSum([4, 6], 10).sort((a, b) => a - b);
//		  chai.expect(output).to.deep.equal([4, 6]);
//		});
//		it('Test Case #2', function () {
//		  const output = program.twoNumberSum([4, 6, 1], 5).sort((a, b) => a - b);
//		  chai.expect(output).to.deep.equal([1, 4]);
//		});
//		it('Test Case #3', function () {
//		  const output = program.twoNumberSum([4, 6, 1, -3], 3).sort((a, b) => a - b);
//		  chai.expect(output).to.deep.equal([-3, 6]);
//		});
//		it('Test Case #4', function () {
//		  const output = program.twoNumberSum([3, 5, -4, 8, 11, 1, -1, 6], 10).sort((a, b) => a - b);
//		  chai.expect(output).to.deep.equal([-1, 11]);
//		});
//		it('Test Case #5', function () {
//		  const output = program.twoNumberSum([1, 2, 3, 4, 5, 6, 7, 8, 9], 17).sort((a, b) => a - b);
//		  chai.expect(output).to.deep.equal([8, 9]);
//		});
//		it('Test Case #6', function () {
//		  const output = program.twoNumberSum([1, 2, 3, 4, 5, 6, 7, 8, 9, 15], 18).sort((a, b) => a - b);
//		  chai.expect(output).to.deep.equal([3, 15]);
//		});
//		it('Test Case #7', function () {
//		  const output = program.twoNumberSum([-7, -5, -3, -1, 0, 1, 3, 5, 7], -5).sort((a, b) => a - b);
//		  chai.expect(output).to.deep.equal([-5, 0]);
//		});
//		it('Test Case #8', function () {
//		  const output = program.twoNumberSum([-21, 301, 12, 4, 65, 56, 210, 356, 9, -47], 163).sort((a, b) => a - b);
//		  chai.expect(output).to.deep.equal([-47, 210]);
//		});
//		it('Test Case #9', function () {
//		  const output = program.twoNumberSum([-21, 301, 12, 4, 65, 56, 210, 356, 9, -47], 164).sort((a, b) => a - b);
//		  chai.expect(output).to.deep.equal([]);
//		});
//		it('Test Case #10', function () {
//		  const output = program.twoNumberSum([3, 5, -4, 8, 11, 1, -1, 6], 15).sort((a, b) => a - b);
//		  chai.expect(output).to.deep.equal([]);
//		});
//		"""
