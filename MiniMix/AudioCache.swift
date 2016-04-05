//
//  AudioCache.swift
//  MiniMix
//
//  Created by Jeff Newell on 3/1/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import Foundation
import UIKit

class AudioCache {
    // MARK: - Helper
    class func trackAudioAsData(track: AudioTrack) -> NSData {
        return NSData(contentsOfURL: AudioCache.trackPath(track, parentSong: track.song!))!
    }
    class func mixedSongAsData(song: SongMix) -> NSData {
        return NSData(contentsOfURL: AudioCache.mixedSongPath(song))!
    }
    
    class func songDirectory(song: SongMix) -> String {
        let documentsDirectoryURL: NSURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
        return documentsDirectoryURL.URLByAppendingPathComponent(song.id).path!
    }
    class func trackPath(track: AudioTrack, parentSong song: SongMix) -> NSURL {
        let pathComponents = [songDirectory(song), "\(track.id).caf"]
        return NSURL.fileURLWithPathComponents(pathComponents)!
    }
    class func mixedSongPath(song: SongMix) -> NSURL {
        let pathComponents = [songDirectory(song), "\(song.name).m4a"]
        return NSURL.fileURLWithPathComponents(pathComponents)!
    }
    
}