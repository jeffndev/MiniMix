//
//  TrackTableViewCell.swift
//  MiniMix
//
//  Created by Jeff Newell on 2/17/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import UIKit

class TrackTableViewCell: UITableViewCell {

    @IBOutlet weak var muteButton: UIButton!
    @IBOutlet weak var eraseButton: UIButton!
    @IBOutlet weak var stopTrackPlayButton: UIButton!
    @IBOutlet weak var playTrackButton: UIButton!
    @IBOutlet weak var trackNameTextView: UITextField!
    @IBOutlet weak var volumeSlider: UISlider!
    @IBOutlet weak var trackProgress: UIProgressView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var stopRecordButton: UIButton!
    
    var muteMode = false
    var track: AudioTrack? {
        didSet {
            playTrackButton.hidden = false
            stopTrackPlayButton.hidden = true
            guard let track = track else {
                return
            }
            playTrackButton.enabled = track.hasRecordedFile
            eraseButton.enabled = track.hasRecordedFile
            muteButton.enabled = track.hasRecordedFile
            trackProgressUpdate()
        }
    }
    var delegate: TrackControllerDelegate?
    
    func trackProgressUpdate() {
        guard let track = track else {
            trackProgress.progress = 0.0
            return
        }
        guard let runLength = track.lengthSeconds else {
            trackProgress.progress = 0.0
            return
        }
        trackProgress.progress = Float(runLength)/Float(SongMixerViewController.MAX_TRACK_SECONDS)
    }
    
    @IBAction func playTrack() {
        guard let delegate = delegate, let track = track else {
            return
        }
        delegate.playTrack(track, atVolume: volumeSlider.value)
        playTrackButton.hidden = true
        stopTrackPlayButton.hidden = false
    }
    @IBAction func stopTrackPlay() {
        guard let delegate = delegate, let track = track else {
            return
        }
        delegate.stopTrackPlayback(track)
        playTrackButton.hidden = false
        stopTrackPlayButton.hidden = true
    }
    @IBAction func eraseTrack() {
        guard let delegate = delegate, let track = track else {
            return
        }
        delegate.eraseTrackRecording(track) { success in
            self.playTrackButton.enabled = self.track!.hasRecordedFile
            self.muteButton.enabled = self.track!.hasRecordedFile
            self.eraseButton.enabled = self.track!.hasRecordedFile
            self.trackProgressUpdate()
        }
    }
    @IBAction func muteTrackPlayback() {
        muteMode = !muteMode
        muteButton.backgroundColor = muteMode ? UIColor.yellowColor() : UIColor.clearColor()
        guard let delegate = delegate, track = track else {
            return
        }
        track.isMuted = muteMode
        delegate.muteTrackPlayback(track, doMute: muteMode)
    }
    @IBAction func beginRecord() {
        guard let delegate = delegate, let track = track else {
            return
        }
        stopRecordButton.hidden = false
        recordButton.hidden = true
        delegate.recordTrack(track) { success in
            if !success {
                self.recordButton.hidden = false
                self.stopRecordButton.hidden = true
            }
        }
    }
    @IBAction func stopRecord() {
        guard let delegate = delegate, let track = track else {
            return
        }
        stopRecordButton.hidden = true
        recordButton.hidden = false
        delegate.stopRecord(track) { success in
            self.setStopRecordUIState()
        }
    }
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        trackNameTextView.delegate = self
        stopRecordButton.hidden = true
        volumeSlider.addTarget(self, action: "volumeChanged", forControlEvents: .ValueChanged)
    }
    
    func volumeChanged() {
        guard let delegate = delegate else {
            return
        }
        delegate.changeTrackVolumne(track!, newVolume: volumeSlider.value)
    }
    
    func setStopRecordUIState() {
        stopRecordButton.hidden = true
        recordButton.hidden = false
        guard let track = track else {
            return
        }
        playTrackButton.enabled = track.hasRecordedFile
        muteButton.enabled = track.hasRecordedFile
        eraseButton.enabled = track.hasRecordedFile
    }
    func setTrackPlayButtonsToReadyToPlayState() {
        stopTrackPlayButton.hidden = true
        playTrackButton.hidden = false
    }
    
    override func setSelected(selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
extension TrackTableViewCell: UITextFieldDelegate {
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    func textFieldDidEndEditing(textField: UITextField) {
        track?.name = textField.text!
    }
}