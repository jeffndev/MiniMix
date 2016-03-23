//
//  SongListingTableViewCell.swift
//  MiniMix
//
//  Created by Jeff Newell on 3/1/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import UIKit

class SongListingTableViewCell: UITableViewCell {
    
    @IBOutlet weak var songTitleLabel: UILabel!
    @IBOutlet weak var songCommentLabel: UITextView!
    @IBOutlet weak var songStarsRankLable: UILabel!
    
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    
    var delegate: SongPlaybackDelegate!
    var song: SongMix!
    
    @IBAction func playMix(sender: AnyObject) {
        guard let song = song, delegate = delegate else {
            return
        }
        setReadyToPlayUIState(false)
        //playButton.hidden = true
        //stopButton.hidden = false
        delegate.playSong(self, song: song)
    }
    @IBAction func stopPlayback(sender: AnyObject) {
        guard let song = song, delegate = delegate else {
            return
        }
        setReadyToPlayUIState(true)
        //playButton.hidden = false
        //stopButton.hidden = true
        delegate.stopSong(self, song: song)
    }
    
    func setReadyToPlayUIState(ready: Bool) {
        playButton.hidden = !ready
        stopButton.hidden = ready
    }
}
