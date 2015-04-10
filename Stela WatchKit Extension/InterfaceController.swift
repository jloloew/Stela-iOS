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


class InterfaceController: WKInterfaceController {

	@IBOutlet weak var pauseImage: WKInterfaceImage!
	@IBOutlet weak var currWord: WKInterfaceButton!
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
	
	// MARK: - Lifecycle
	
    override func awakeWithContext(context: AnyObject?) {
        super.awakeWithContext(context)
        
        // Configure interface objects here.
		// the pause icon is just to make storyboarding easier, it should be clear by default
		pauseImage.setImageNamed(nil)
		// TODO: Long words in currWord wrap to a new line. Make the font size compress instead.
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
		
		getWordList()
		
		changeWord()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
	
	// MARK: - UI
	
	@IBAction func playPause() {
		if paused {
			playTapped()
		} else {
			pauseTapped()
		}
	}
	
	@IBAction func playTapped() {
		shouldPause = false
		changeWord()
	}
	
	@IBAction func pauseTapped() {
		shouldPause = true
	}
	
	func setPlayPauseIcon() {
		if paused {
			pauseImage.setImageNamed("Pause")
		} else if rewinding {
			pauseImage.setImageNamed("Rewind")
		} else {
//			pauseImage.setImageNamed("Play")
		}
	}
	
	// MARK: -
	
	func changeWord() {
		// check if we should pause reading
		if shouldPause {
			paused = true
			return
		} else if paused {
			paused = false
		}
		
		if let nextWord = wordManager.nextWord() {
			currWord.setTitle(nextWord)
			infoText.setText(nil)
			// schedule the callback to display the next word
			let wordsPerMinute = 150
			let wordChangePeriod = 60.0 / Float(wordsPerMinute) // in Hz
			let callbackTime = dispatch_time(DISPATCH_TIME_NOW, Int64(wordChangePeriod * Float(NSEC_PER_SEC)))
			dispatch_after(callbackTime, dispatch_get_main_queue(), { () -> Void in
				self.changeWord()
			})
		} else {
			currWord.setTitle(nil)
			infoText.setText("Done reading.")
		}
	}
	
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
