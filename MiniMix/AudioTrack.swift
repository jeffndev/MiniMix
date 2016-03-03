//
//  AudioTrack.swift
//  MiniMix
//
//  Created by Jeff Newell on 2/17/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import UIKit

class AudioTrack: NSObject {
    enum TrackType {
        case MIX
        case MASTER
    }
    
    var id: NSUUID
    var name: String
    var createDate: NSDate
    var trackType: TrackType
    var trackDescription: String?
    var lengthSeconds: Double?
    var mixVolume: Float
    var hasRecordedFile: Bool
    //var song: SongMix?
    var isMuted = false //non-persistant
    
    init(trackName: String, type: TrackType, trackDescription: String?) {
        name = trackName
        self.trackDescription = trackDescription
        trackType = type
        createDate = NSDate()
        id = NSUUID()
        mixVolume = 1.0
        hasRecordedFile = false
    }
}
