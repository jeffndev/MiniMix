//
//  AudioTrackDTO.swift
//  MiniMix
//
//  Created by Jeff Newell on 4/7/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import Foundation

struct AudioTrackDTO {
    
    var id: String//NSUUID
    var name: String
    var createDate: NSDate
    var displayOrder: Int32
    var trackDescription: String?
    var lengthSeconds: NSNumber? //Double?
    var mixVolume: NSNumber //Float
    var hasRecordedFile: Bool

    var trackFileUrl: String?
    var s3RandomId: String?
    
    
    init(trackObject: AudioTrack) {
        id = trackObject.id
        name = trackObject.name
        createDate = trackObject.createDate
        displayOrder = trackObject.displayOrder
        trackDescription = trackObject.trackDescription
        lengthSeconds = trackObject.lengthSeconds
        mixVolume = trackObject.mixVolume
        hasRecordedFile = trackObject.hasRecordedFile
        trackFileUrl = trackObject.trackFileUrl
        s3RandomId = trackObject.s3RandomId
    }
}
