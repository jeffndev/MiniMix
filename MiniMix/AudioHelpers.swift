//
//  AudioHelpers.swift
//  MiniMix
//
//  Created by Jeff Newell on 3/16/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import AVFoundation


struct AudioHelpers {
    //TODO: put the Path helpers in here too..
    
    
    static func createSongMixFile(song: SongMix, postHandler: (success: Bool) -> Void) {
        let composition = AVMutableComposition()
        var inputMixParms = [AVAudioMixInputParameters]()
        for track in song.tracks {
            let trackUrl = AudioCache.trackPath(track, parentSong: song)
            let audioAsset = AVURLAsset(URL: trackUrl)
            let audioCompositionTrack = composition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
            do {
                try audioCompositionTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, audioAsset.duration), ofTrack: audioAsset.tracksWithMediaType(AVMediaTypeAudio).first!, atTime: kCMTimeZero)
            }catch {
                postHandler(success: false)
                return
            }
            let mixParm = AVMutableAudioMixInputParameters(track: audioCompositionTrack)
            inputMixParms.append(mixParm)
        }
        //EXPORT
        //TODO: change this to export mp3's because I can't, generally, attach m4a's to audio tags in web pages, and I want that for the web site portal
        //      here's one possible way: http://stackoverflow.com/questions/24111026/avassetexportsession-export-mp3-while-keeping-metadata
        //      change type to ...Passthrough, then change file type to com.apple.quicktime-movie, then rename file to .mp3 ending
        let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A)
        let mixUrl = AudioCache.mixedSongPath(song)
        do {
            try NSFileManager.defaultManager().removeItemAtPath(mixUrl.path!)
        } catch {
            
        }
        if let export = export {
            let mixParms = AVMutableAudioMix()
            mixParms.inputParameters = inputMixParms
            export.audioMix = mixParms
            //TODO: change to: com.apple.quicktime-movie
            export.outputFileType = AVFileTypeAppleM4A
            export.outputURL = mixUrl
            export.exportAsynchronouslyWithCompletionHandler {
                if export.status == .Completed {
                    postHandler(success: true)
                    print("EXPORTED success..try to play it now")
                } else {
                    postHandler(success: false)
                    print("EXPORT file mix failed..")
                }
            }
        }
    }
    
    
}

