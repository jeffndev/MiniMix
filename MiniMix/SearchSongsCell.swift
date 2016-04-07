//
//  SearchSongsCell.swift
//  MiniMix
//
//  Created by Jeff Newell on 3/22/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import UIKit

class SearchSongsCell: UITableViewCell {
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var songArtistLabel: UILabel!
    @IBOutlet weak var songNameLabel: UILabel!
    @IBOutlet weak var genreLabel: UILabel!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var delegate: SongSearchPlaybackDelegate?
    var songInfo: SongMixDTO?
    
    @IBAction func playMix() {
        guard let delegate = delegate, let songInfo = songInfo else {
            return
        }
        
        delegate.playSong(self, song: songInfo)
    }
    @IBAction func stopPlay() {
        guard let delegate = delegate, let songInfo = songInfo else {
            return
        }
        delegate.stopSong(self, song: songInfo)
    }
    
    @IBAction func downloadSong() {
        guard let delegate = delegate, let songInfo = songInfo else {
            return
        }
        delegate.downloadSong(self, song: songInfo)
    }
    
    func setDisabledStateForFailedMixPreviewDownload(doDisable: Bool) {
        self.contentView.alpha = doDisable ?  0.3 : 1.0
    }
    
    func setReadyToPlayUIState(ready: Bool) {
        self.playButton.hidden = !ready
        self.stopButton.hidden = ready
        self.playButton.enabled = ready
    }
    func setBusyState(isBusy: Bool) {
        activityIndicator.hidden = !isBusy
        if isBusy {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
        self.contentView.alpha = isBusy ? 0.3 : 1.0 
    }
}
