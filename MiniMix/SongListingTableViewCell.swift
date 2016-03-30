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
    //optional items...
    @IBOutlet weak var artistName: UILabel!
    @IBOutlet weak var syncButton: UIButton!
    
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    
    var delegate: SongPlaybackDelegate!
    var song: SongMix!
    
    @IBAction func playMix(sender: AnyObject) {
        guard let song = song, delegate = delegate else {
            return
        }
        setReadyToPlayUIState(false)
        delegate.playSong(self, song: song)
    }
    @IBAction func stopPlayback(sender: AnyObject) {
        guard let song = song, delegate = delegate else {
            return
        }
        setReadyToPlayUIState(true)
        delegate.stopSong(self, song: song)
    }
    @IBAction func syncSongToCloud() {
        guard let song = song, delegate = delegate else {
            return
        }
        delegate.syncSongWithCloud(self, song: song)
    }
    func setReadyToPlayUIState(ready: Bool) {
        print(ready)
        dispatch_async(dispatch_get_main_queue()) {
            self.playButton.hidden = !ready
            self.stopButton.hidden = ready
            self.playButton.enabled = ready
        }
    }
    func setSyncWarningState(shouldSync: Bool) {
        //TODO:
        if let syncButton = syncButton {
            syncButton.hidden = !shouldSync
        }
    }
}
