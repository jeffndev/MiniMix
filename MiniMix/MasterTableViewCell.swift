//
//  MasterTableViewCell.swift
//  MiniMix
//
//  Created by Jeff Newell on 2/17/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import UIKit

class MasterTableViewCell: UITableViewCell {

    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var playButton: UIButton!
    
    var delegate: MasterPlaybackControllerDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    @IBAction func playMix() {
        guard let delegate = delegate else {
            return
        }
        delegate.playMix(self)
    }
    @IBAction func stopPlay() {
        guard let delegate = delegate else {
            return
        }
        delegate.stopMixPlayback(self)
    }
    func setIsReadyState(isReadyToPlay ready: Bool) {
        playButton.hidden = !ready
        stopButton.hidden = ready
    }
}
