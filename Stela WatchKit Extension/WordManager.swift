//
//  WordManager.swift
//  Stela
//
//  Created by Justin Loew on 4/3/15.
//  Copyright (c) 2015 Justin Loew. All rights reserved.
//

import Foundation


class WordManager {
	
	var words = [String]()
	private var currWordIndex = 0
	
	var isValid: Bool {
		return !words.isEmpty
	}
	
	required init?(serializedWordsAtURL wordsURL: NSURL) {
		if let wordsArray = NSArray(contentsOfURL: wordsURL) {
			words = wordsArray as [String]
		} else {
			return nil
		}
	}
	
	func nextWord() -> String? {
		if currWordIndex < words.count {
			return words[currWordIndex++]
		} else {
			return nil
		}
	}
	
	/// Check the list of words for any words that are too long to display on a single screen. Excessively long words are hyphenated and split into two.
	func fixWordLengthsIfNecessary() {
		
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
