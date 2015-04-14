//
//  InterfaceController.swift
//  Stela WatchKit Extension
//
//  Created by Justin Loew on 4/3/15.
//  Copyright (c) 2015 Justin Loew. All rights reserved.
//

import WatchKit
import Foundation


private let sharedWordsFileName = "sharedWords"
private let AppleWatchHasConnectedKey = "Apple Watch has connected"
private let SavedWordsPerMinuteKey = "Last WPM"
private let infoTextDisplayDuration: NSTimeInterval = 3.0 // seconds
private let minReadingSpeed = 60 // words per minute
private let maxReadingSpeed = 800 // words per minute


class InterfaceController: WKInterfaceController {

	@IBOutlet weak var pauseImage: WKInterfaceImage!
	@IBOutlet weak var currWord: WKInterfaceLabel!
	@IBOutlet weak var infoText: WKInterfaceLabel!
	
	var wordManager: WordManager!
	
	var rewinding = false {
		didSet {
			setPlayPauseIcon()
		}
	}
	var paused = false {
		didSet {
			setPlayPauseIcon()
		}
	}
	private var shouldPause = false
	
	/// The current reading speed, in words per minute. This value is automatically persisted.
	var wordsPerMinute = 200 {
		didSet {
			if let defaults = NSUserDefaults(suiteName: "group.stela.text") {
				defaults.setInteger(wordsPerMinute, forKey: SavedWordsPerMinuteKey)
			}
		}
	}
	
	// MARK: - Lifecycle
	
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
		
		// load settings
		if let defaults = NSUserDefaults(suiteName: "group.stela.text") {
			// Write a value so the phone knows an Apple Watch has connected
			if nil == defaults.valueForKey(AppleWatchHasConnectedKey) {
				defaults.setBool(true, forKey: AppleWatchHasConnectedKey)
			}
			// load last reading speed
			let savedWPM = defaults.integerForKey(SavedWordsPerMinuteKey)
			if savedWPM != 0 {
				wordsPerMinute = savedWPM
			}
		}
		
		pauseImage.setImageNamed(nil)
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
		
		getWordList()
		
		// test whether we have anything to read
		if let testWord = wordManager.nextWord() {
			wordManager.prevWord() // rewind
			setInfoText(nil)
			changeWord()
		} else {
			currWord.setText(nil)
			setInfoText("Nothing to read.")
		}
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
	
	// MARK: - UI
	
	@IBAction func incrementReadingSpeed() {
		if wordsPerMinute + 20 <= maxReadingSpeed {
			wordsPerMinute += 20
		}
		setInfoText("\(wordsPerMinute) words per minute", duration: infoTextDisplayDuration)
	}
	
	@IBAction func decrementReadingSpeed() {
		if wordsPerMinute - 20 >= minReadingSpeed {
			wordsPerMinute -= 20
		}
		setInfoText("\(wordsPerMinute) words per minute", duration: infoTextDisplayDuration)
	}
	
	/// Toggle between paused and reading states.
	@IBAction func playPause() {
		if paused {
			play()
		} else {
			pause()
		}
	}
	
	/// Start or resume reading.
	func play() {
		shouldPause = false
		changeWord()
	}
	
	/// Temporarily stop reading without losing our place.
	func pause() {
		shouldPause = true
	}
	
	/// Set the correct icon for the current reading state.
	func setPlayPauseIcon() {
		if paused {
			pauseImage.setImageNamed("Pause")
		} else if rewinding {
			pauseImage.setImageNamed("Rewind")
		} else {
//			pauseImage.setImageNamed("Play")
			pauseImage.setImage(nil)
		}
	}
	
	/// Set the info text and automatically hide it after a period of time.
	/// 
	/// :param: text The new text to set.
	/// :param: duration How long to show the new text for, in seconds. Pass a negative value for permanent text.
	func setInfoText(text: String?, duration: NSTimeInterval = 0.0) {
		infoText.setText(text)
		_infoTextString = text // Workaround. See declaration.
		
		// remove previous timer
		if infoTextTimer != nil {
			infoTextTimer.invalidate()
			infoTextTimer = nil
		}
		
		if duration > 0.0 {
			// set up timer
			infoTextTimer = NSTimer.scheduledTimerWithTimeInterval(duration, target: self, selector: "_setInfoText:", userInfo: nil, repeats: false)
		}
	}
	private var infoTextTimer: NSTimer!
	@objc
	private func _setInfoText(timer: NSTimer!) {
		setInfoText(nil, duration: -1.0)
	}
	
	// MARK: -
	
	/// Display the next word (or previous word, if rewinding).
	/// This function is called on a timer to update the word.
	func changeWord() {
		// check if we should pause reading
		if shouldPause {
			paused = true
			return
		} else if paused {
			paused = false
		}
		
		let nextWord: String?
		if rewinding {
			nextWord = wordManager.prevWord()
		} else {
			nextWord = wordManager.nextWord()
		}
		
		if let nextWord = nextWord {
			currWord.setText(nextWord)
			// schedule the callback to display the next word
			let wordChangePeriod = 1.0 / (Float(wordsPerMinute) / 60.0) // in Hz
			let callbackTime = dispatch_time(DISPATCH_TIME_NOW, Int64(wordChangePeriod * Float(NSEC_PER_SEC)))
			dispatch_after(callbackTime, dispatch_get_main_queue()) {
				self.changeWord()
			}
		} else {
			currWord.setText(nil)
			setInfoText("Done reading.")
		}
	}
	private var _infoTextString: String! // workaround because we can't get the text in a WKInterfaceLabel
	
	/// Get the shared text to read from the main Stela app.
	func getWordList() {
		let fileManager = NSFileManager.defaultManager()
		if let containerURL = fileManager.containerURLForSecurityApplicationGroupIdentifier("group.stela.text") {
			if let sharedWordsURL = NSURL(string: sharedWordsFileName, relativeToURL: containerURL) {
				wordManager = WordManager(serializedWordsAtURL: sharedWordsURL)
			}
		}
	}

}
