//
//  SongListingTableViewCell.swift
//  MiniMix
//
//  Created by Jeff Newell on 3/1/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import UIKit

class SongListingTableViewCell: UITableViewCell {
    
    let SYNC_WARNING_COLOR = UIColor(colorLiteralRed: 1, green: 0.6, blue: 0.4, alpha: 1)
    
    @IBOutlet weak var songTitleLabel: UILabel!
    @IBOutlet weak var songCommentLabel: UITextView!
    @IBOutlet weak var songStarsRankLable: UILabel!
    //optional items...
    @IBOutlet weak var artistName: UILabel!
    @IBOutlet weak var syncButton: UIButton!
    
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
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
        //dispatch_async(dispatch_get_main_queue()) {
            playButton.hidden = !ready
            stopButton.hidden = ready
            playButton.enabled = ready
        //}
    }
    func setSyncWarningState(shouldSync: Bool) {
        if let syncButton = syncButton {
            syncButton.backgroundColor = shouldSync ? SYNC_WARNING_COLOR : UIColor.clearColor()
        }
    }
    func setUploadedState(wasUploaded: Bool) {
        if let syncButton = syncButton {
            syncButton.layer.cornerRadius = 8
            syncButton.layer.borderWidth = 0
            syncButton.hidden = !wasUploaded
        }
    }
    func setBusyState(isBusy: Bool) {
        if let activityIndicator = activityIndicator {
            activityIndicator.hidden = !isBusy
            if isBusy {
                activityIndicator.startAnimating()
            } else {
                activityIndicator.stopAnimating()
            }
        }
        self.contentView.alpha = isBusy ? 0.3 : 1.0
    }
}
