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
    class func trackAudioAsData(trackId: String, parentSongId songId: String) -> NSData? {
        return NSData(contentsOfURL: AudioCache.trackPath(trackId, parentSongId: songId))
    }
    
    class func mixedSongAsData(songId: String, songName: String) -> NSData? {
        return NSData(contentsOfURL: AudioCache.mixedSongPath(songId, songName: songName))
    }
    
    class func songDirectory(songId: String) -> String {
        let documentsDirectoryURL: NSURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
        return documentsDirectoryURL.URLByAppendingPathComponent(songId).path!
    }
    
    class func trackPath(trackId: String, parentSongId songId: String) -> NSURL {
        let pathComponents = [songDirectory(songId), "\(trackId).caf"]
        return NSURL.fileURLWithPathComponents(pathComponents)!
    }
    class func mixedSongPath(songId: String, songName: String) -> NSURL {
        let pathComponents = [songDirectory(songId), "\(songName).m4a"]
        return NSURL.fileURLWithPathComponents(pathComponents)!
    }
    
    class func downSyncUserSongFile(songId: String, songName: String, songFileRemoteUrl mixUrl: String?) {
        //create subdirectory in Documents for the SONG, the tracks and mix go in there...
        if !NSFileManager.defaultManager().fileExistsAtPath(AudioCache.songDirectory(songId)) {
            do {
                try NSFileManager.defaultManager().createDirectoryAtPath(AudioCache.songDirectory(songId), withIntermediateDirectories: true, attributes: nil)
            } catch let error as NSError {
                print("could not create song directory, not able to prepare for recording: \(error.localizedDescription)")
                return
            }
        }
        guard !NSFileManager.defaultManager().fileExistsAtPath(AudioCache.mixedSongPath(songId, songName: songName).path!) else {
            print("mix file already exists locally, not downloading")
            return
        }
        guard let songUrl = mixUrl else {
            return
        }
        guard let songData = NSData(contentsOfURL: NSURL(string: songUrl)!) else {
            return
        }
        songData.writeToURL(AudioCache.mixedSongPath(songId, songName: songName), atomically: true)
        print("mix file for song: \(songName) downloaded locally with Sync")
    }
    
    class func downSyncUserTrackFile(trackId: String, parentSongId: String, trackRemoteUrl: String?) {
        //create subdirectory in Documents for the SONG, the tracks and mix go in there...
        if !NSFileManager.defaultManager().fileExistsAtPath(AudioCache.songDirectory(parentSongId)) {
            do {
                try NSFileManager.defaultManager().createDirectoryAtPath(AudioCache.songDirectory(parentSongId), withIntermediateDirectories: true, attributes: nil)
            } catch let error as NSError {
                print("could not create song directory, not able to prepare for recording: \(error.localizedDescription)")
                return
            }
        }
        guard !NSFileManager.defaultManager().fileExistsAtPath(AudioCache.trackPath(trackId, parentSongId: parentSongId).path!) else {
            print("track file already exists locally, not downloading")
            return
        }
        guard let trackUrl = trackRemoteUrl else {
            return
        }
        guard let trackData = NSData(contentsOfURL: NSURL(string: trackUrl)!) else {
            return
        }
        trackData.writeToURL(AudioCache.trackPath(trackId, parentSongId: parentSongId), atomically: true)
    }

    
}