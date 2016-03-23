//
//  SearchSongsCell.swift
//  MiniMix
//
//  Created by Jeff Newell on 3/22/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import UIKit

class SearchSongsCell: UITableViewCell {
    @IBOutlet weak var displayLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!
    
    var delegate: SongSearchPlaybackDelegate?
    var songInfo: SongMixLite?
    
    @IBAction func playMix() {
        guard let delegate = delegate, let songInfo = songInfo else {
            return
        }
        delegate.playSong(self, song: songInfo)
    }
    @IBAction func downloadSong() {
        guard let delegate = delegate, let songInfo = songInfo else {
            return
        }
        delegate.downloadSong(self, song: songInfo)
    }
}
