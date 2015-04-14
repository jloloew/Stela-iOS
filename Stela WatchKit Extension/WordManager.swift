//
//  WordManager.swift
//  Stela
//
//  Created by Justin Loew on 4/3/15.
//  Copyright (c) 2015 Justin Loew. All rights reserved.
//

import Foundation


private let maxWordLength = 9


class WordManager {
	
	var words = [String]()
	private var currWordIndex = 0
	
	var isValid: Bool {
		return !words.isEmpty
	}
	
	required init(serializedWordsAtURL wordsURL: NSURL) {
		if let wordsArray = NSArray(contentsOfURL: wordsURL) {
			words = wordsArray as! [String]
		} else {
			println("\(__FUNCTION__): Unable to load words from file.")
		}
	}
	
	func nextWord() -> String? {
		if currWordIndex < words.count {
			return words[currWordIndex++]
		} else {
			return nil
		}
	}
	
	func prevWord() -> String? {
		if currWordIndex > 0 {
			return words[currWordIndex--]
		} else {
			return nil
		}
	}
	
	/// Check the list of words for any words that are too long to display on a single screen. Excessively long words are hyphenated and split into two.
	func fixWordLengthsIfNecessary() {
		for i in 0 ..< words.count {
			if count(words[i]) > maxWordLength {
				let original = words[i]
				words[i] = original[0 ..< maxWordLength - 1] + "–"
				let newWord = "–" + original.substringFromIndex(advance(original.startIndex, maxWordLength - 1))
				words.insert(newWord, atIndex: i)
			}
		}
	}
	
}

extension WordManager : Printable, DebugPrintable {
	var description: String {
		if words.isEmpty {
			return "{ }"
		} else {
			var desc = "{\n"
			for i in 0 ..< words.count {
				desc += "(\(i)):\t\"\(words[i])\",\n"
			}
			desc += "}"
			return desc
		}
	}
	
	var debugDescription: String {
		return description
	}
}

/// Enable String subscripting.
// source: https://stackoverflow.com/questions/24044851/how-do-you-use-string-substringwithrange-or-how-do-ranges-work-in-swift
extension String {
	subscript(r: Range<Int>) -> String {
		get {
			let startIndex = advance(self.startIndex, r.startIndex)
			let endIndex = advance(startIndex, r.endIndex - r.startIndex)
			
			return self[Range(start: startIndex, end: endIndex)]
		}
	}
}
