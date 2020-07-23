//
//  CodeCompleteTests.swift
//  CodeCompleteTests
//
//  Copyright © 2020 Vijay Sharma. All rights reserved.
//

import XCTest

class CodeCompleteTests: XCTestCase {
//    func testExample() throws {
//		let url = Bundle.main.url(forResource: "question-list", withExtension: "json")!
//		let data = try! Data(contentsOf: url)
//		let questions: QuestionList = try! JSONDecoder().decode(QuestionList.self, from: data)
//		XCTAssert(questions.Problems.count > 0)
//
//		for problem in questions.Problems {
//			let name = problem.Name.lowercased().replacingOccurrences(of: " ", with: "-")
//			self.assertQuestions(name: name)
//		}
//    }

	// TODO: Fix the tests for these
//	func testBSTConstruction() throws {
//		self.assertQuestions(name: "bst-construction")
//	}
//
//	func testLinkedListConstruction() throws {
//		self.assertQuestions(name: "linked-list-construction")
//	}

	func testAirportConnections() throws {
		self.assertQuestions(name: "airport-connections")
	}

	func testAllKindsOfNodeDepths() throws {
		self.assertQuestions(name: "all-kinds-of-node-depths")
	}

	func testApartmentHunting() throws {
		self.assertQuestions(name: "apartment-hunting")
	}

	func testBalancedBrackets() throws {
		self.assertQuestions(name: "balanced-brackets")
	}

	func testBinarySearch() throws {
		self.assertQuestions(name: "binary-search")
	}

	func testBoggleBoard() throws {
		self.assertQuestions(name: "boggle-board")
	}

	func testBranchSums() throws {
		self.assertQuestions(name: "branch-sums")
	}

	func testBreadthfirstSearch() throws {
		self.assertQuestions(name: "breadth-first-search")
	}

	func testBSTTraversal() throws {
		self.assertQuestions(name: "bst-traversal")
	}

	func testBubbleSort() throws {
		self.assertQuestions(name: "bubble-sort")
	}

	func testCaesarCipherEncryptor() throws {
		self.assertQuestions(name: "caesar-cipher-encryptor")
	}

	func testCalendarMatching() throws {
		self.assertQuestions(name: "calendar-matching")
	}

	func testContinuousMedian() throws {
		self.assertQuestions(name: "continuous-median")
	}

	func testDepthfirstSearch() throws {
		self.assertQuestions(name: "depth-first-search")
	}

	func testDiskStacking() throws {
		self.assertQuestions(name: "disk-stacking")
	}

	func testFindClosestValueInBST() throws {
		self.assertQuestions(name: "find-closest-value-in-bst")
	}

	func testFindLoop() throws {
		self.assertQuestions(name: "find-loop")
	}

	func testFindThreeLargestNumbers() throws {
		self.assertQuestions(name: "find-three-largest-numbers")
	}

	func testFlattenBinaryTree() throws {
		self.assertQuestions(name: "flatten-binary-tree")
	}

	func testFourNumberSum() throws {
		self.assertQuestions(name: "four-number-sum")
	}

	func testGroupAnagrams() throws {
		self.assertQuestions(name: "group-anagrams")
	}

	func testHeapSort() throws {
		self.assertQuestions(name: "heap-sort")
	}

	func testInsertionSort() throws {
		self.assertQuestions(name: "insertion-sort")
	}

	func testInterweavingStrings() throws {
		self.assertQuestions(name: "interweaving-strings")
	}

	func testInvertBinaryTree() throws {
		self.assertQuestions(name: "invert-binary-tree")
	}

	func testIterativeInorderTraversal() throws {
		self.assertQuestions(name: "iterative-in-order-traversal")
	}

	func testKadanesAlgorithm() throws {
		self.assertQuestions(name: "kadane's-algorithm")
	}

	func testKnapsackProblem() throws {
		self.assertQuestions(name: "knapsack-problem")
	}

	func testKnuthMorrisPrattAlgorithm() throws {
		self.assertQuestions(name: "knuth—morris—pratt-algorithm")
	}

	func testLargestRange() throws {
		self.assertQuestions(name: "largest-range")
	}

	func testLevenshteinDistance() throws {
		self.assertQuestions(name: "levenshtein-distance")
	}

	func testLongestCommonSubsequence() throws {
		self.assertQuestions(name: "longest-common-subsequence")
	}

	func testLongestIncreasingSubsequence() throws {
		self.assertQuestions(name: "longest-increasing-subsequence")
	}

	func testLongestPalindromicSubstring() throws {
		self.assertQuestions(name: "longest-palindromic-substring")
	}

	func testLongestPeak() throws {
		self.assertQuestions(name: "longest-peak")
	}

	func testLongestStringChain() throws {
		self.assertQuestions(name: "longest-string-chain")
	}

	func testLongestSubstringWithoutDuplication() throws {
		self.assertQuestions(name: "longest-substring-without-duplication")
	}

	func testLowestCommonManager() throws {
		self.assertQuestions(name: "lowest-common-manager")
	}

	func testLRUCache() throws {
		self.assertQuestions(name: "lru-cache")
	}

	func testMaxPathSumInBinaryTree() throws {
		self.assertQuestions(name: "max-path-sum-in-binary-tree")
	}

	func testMaxProfitWithKTransactions() throws {
		self.assertQuestions(name: "max-profit-with-k-transactions")
	}

	func testMaxSubsetSumNoAdjacent() throws {
		self.assertQuestions(name: "max-subset-sum-no-adjacent")
	}

	func testMaxSumIncreasingSubsequence() throws {
		self.assertQuestions(name: "max-sum-increasing-subsequence")
	}

	func testMergeLinkedLists() throws {
		self.assertQuestions(name: "merge-linked-lists")
	}

	func testMergeSort() throws {
		self.assertQuestions(name: "merge-sort")
	}

	func testMergeSortedArrays() throws {
		self.assertQuestions(name: "merge-sorted-arrays")
	}

	func testMinHeapConstruction() throws {
		self.assertQuestions(name: "min-heap-construction")
	}

	func testMinHeightBST() throws {
		self.assertQuestions(name: "min-height-bst")
	}

	func testMinMaxStackConstruction() throws {
		self.assertQuestions(name: "min-max-stack-construction")
	}

	func testMinNumberOfCoinsForChange() throws {
		self.assertQuestions(name: "min-number-of-coins-for-change")
	}

	func testMinNumberOfJumps() throws {
		self.assertQuestions(name: "min-number-of-jumps")
	}

	func testMinRewards() throws {
		self.assertQuestions(name: "min-rewards")
	}

	func testMonotonicArray() throws {
		self.assertQuestions(name: "monotonic-array")
	}

	func testMoveElementToEnd() throws {
		self.assertQuestions(name: "move-element-to-end")
	}

	func testMultiStringSearch() throws {
		self.assertQuestions(name: "multi-string-search")
	}

	func testNodeDepths() throws {
		self.assertQuestions(name: "node-depths")
	}

	func testNthFibonacci() throws {
		self.assertQuestions(name: "nth-fibonacci")
	}

	func testNumberOfBinaryTreeTopologies() throws {
		self.assertQuestions(name: "number-of-binary-tree-topologies")
	}

	func testNumberOfWaysToMakeChange() throws {
		self.assertQuestions(name: "number-of-ways-to-make-change")
	}

	func testNumbersInPi() throws {
		self.assertQuestions(name: "numbers-in-pi")
	}

	func testPalindromeCheck() throws {
		self.assertQuestions(name: "palindrome-check")
	}

	func testPalindromePartitioningMinCuts() throws {
		self.assertQuestions(name: "palindrome-partitioning-min-cuts")
	}

	func testPatternMatcher() throws {
		self.assertQuestions(name: "pattern-matcher")
	}

	func testPermutations() throws {
		self.assertQuestions(name: "permutations")
	}

	func testPowerset() throws {
		self.assertQuestions(name: "powerset")
	}

	func testProductSum() throws {
		self.assertQuestions(name: "product-sum")
	}

	func testQuickSort() throws {
		self.assertQuestions(name: "quick-sort")
	}

	func testQuickselect() throws {
		self.assertQuestions(name: "quickselect")
	}

	func testRearrangeLinkedList() throws {
		self.assertQuestions(name: "rearrange-linked-list")
	}

	func testRectangleMania() throws {
		self.assertQuestions(name: "rectangle-mania")
	}

	func testRemoveKthNodeFromEnd() throws {
		self.assertQuestions(name: "remove-kth-node-from-end")
	}

	func testReverseLinkedList() throws {
		self.assertQuestions(name: "reverse-linked-list")
	}

	func testRightSiblingTree() throws {
		self.assertQuestions(name: "right-sibling-tree")
	}

	func testRightSmallerThan() throws {
		self.assertQuestions(name: "right-smaller-than")
	}

	func testRiverSizes() throws {
		self.assertQuestions(name: "river-sizes")
	}

	func testSameBSTs() throws {
		self.assertQuestions(name: "same-bsts")
	}

	func testSearchForRange() throws {
		self.assertQuestions(name: "search-for-range")
	}

	func testSearchInSortedMatrix() throws {
		self.assertQuestions(name: "search-in-sorted-matrix")
	}

	func testSelectionSort() throws {
		self.assertQuestions(name: "selection-sort")
	}

	func testShiftLinkedList() throws {
		self.assertQuestions(name: "shift-linked-list")
	}

	func testShiftedBinarySearch() throws {
		self.assertQuestions(name: "shifted-binary-search")
	}

	func testShortenPath() throws {
		self.assertQuestions(name: "shorten-path")
	}

	func testSingleCycleCheck() throws {
		self.assertQuestions(name: "single-cycle-check")
	}

	func testSmallestDifference() throws {
		self.assertQuestions(name: "smallest-difference")
	}

	func testSmallestSubstringContaining() throws {
		self.assertQuestions(name: "smallest-substring-containing")
	}

	func testSpiralTraverse() throws {
		self.assertQuestions(name: "spiral-traverse")
	}

	func testSquareofZeroes() throws {
		self.assertQuestions(name: "square-of-zeroes")
	}

	func testSubarraySort() throws {
		self.assertQuestions(name: "subarray-sort")
	}

	func testSuffixTrieConstruction() throws {
		self.assertQuestions(name: "suffix-trie-construction")
	}

	func testThreeNumberSum() throws {
		self.assertQuestions(name: "three-number-sum")
	}

	func testTopologicalSort() throws {
		self.assertQuestions(name: "topological-sort")
	}

	func testTwoNumberSum() throws {
		self.assertQuestions(name: "two-number-sum")
	}

	func testUnderscorifySubstring() throws {
		self.assertQuestions(name: "underscorify-substring")
	}

	func testValidateBST() throws {
		self.assertQuestions(name: "validate-bst")
	}

	func testValidateSubsequence() throws {
		self.assertQuestions(name: "validate-subsequence")
	}

	func testWaterArea() throws {
		self.assertQuestions(name: "water-area")
	}

	func testYoungestCommonAncestor() throws {
		self.assertQuestions(name: "youngest-common-ancestor")
	}

	func testZigzagTraverse() throws {
		self.assertQuestions(name: "zigzag-traverse")
	}

	private func assertQuestions(name: String) {
		let url = Bundle.main.url(forResource: name, withExtension: "json")!
		let data = try! Data(contentsOf: url)
//			let question: Question = try! JSONDecoder().decode(Question.self, from: data)
		let json = try! JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
		let question = Question(data: json)
		
		let tests = question.JSONTests
		let answers = question.JSONAnswers
		XCTAssertTrue(tests.count == answers.count, "\(question.Summary.Name): Tests and Answer count don't match")
		XCTAssertTrue(tests.count != 0, "\(question.Summary.Name): No tests found for")
		
		let engine = CodeEngine()
		let code = question.Resources.javascript.Solutions[0]
		
		let expect = expectation(description: "\(question.Summary.Name) Code execution")
		engine.run(code: code, question: question) { result in
			switch result {
			case .success(let results):
				results.tests.forEach { result in
					XCTAssertTrue(result.success, "\(result.name) from '\(question.Summary.Name)' failed because \(result.message ?? "unknown")")
				}
				XCTAssertEqual(tests.count, results.tests.count, "Problem with '\(question.Summary.Name)': StartingTest and JSONTests don't match")
			case .failure(let error):
				XCTFail("\(error)")
			}
			expect.fulfill()
		}
		wait(for: [expect], timeout: 10)
	}
}
