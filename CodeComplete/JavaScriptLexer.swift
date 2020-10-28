//
//  JavaScriptLexer.swift
//  CodeComplete
//
//  Copyright © 2020 Vijay Sharma. All rights reserved.
//

import Foundation
import Sourceful

class JavaScriptSyntax: SyntaxTextViewDelegate {
	private let lexer = JavaScriptLexer()
	func lexerForSource(_ source: String) -> Lexer {
		lexer
	}
}

class XJavaScriptLexer: SourceCodeRegexLexer {
	public func generators(source: String) -> [TokenGenerator] {
		var generators = [TokenGenerator?]()
		
		let keywords = "if|else|while|do|for|return|in|instanceof|function|new|try|throw|catch|finally|null|break|continue|catch|finally|as|await|break|case|class|const|continue|debugger|default|delete|do|else|enum|export|extends|for|from|function||if|implements|import|in|instanceof|interface|let|new|null|of|package|private|protected|public|return|static|super|switch|this|throw|try|typeof|undefined|var|void|while|with|yield".components(separatedBy: "|")
		generators.append(keywordGenerator(keywords, tokenType: .keyword))
		
		// Line comment
		generators.append(regexGenerator("//(.*)", tokenType: .comment))
		
		// Block comment
		generators.append(regexGenerator("(/\\*)(.*)(\\*/)", options: [.dotMatchesLineSeparators], tokenType: .comment))
		
		// Single-line string literal
		generators.append(regexGenerator("(\"|@\")[^\"\\n]*(@\"|\")", tokenType: .string))
		// Single-line string literal
		generators.append(regexGenerator("(\'|@\')[^\'\\n]*(@\'|\')", tokenType: .string))
		
		generators.append(regexGenerator("(?<=(\\s|\\[|,|:))(\\d|\\.|_)+", tokenType: .number))
		generators.append(regexGenerator("(true|false)", tokenType: .number))
		
		return generators.compactMap( { $0 })
	}
}
