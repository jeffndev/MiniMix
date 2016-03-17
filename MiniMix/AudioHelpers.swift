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
            export.outputFileType = AVFileTypeAppleM4A
            export.outputURL = mixUrl
            export.exportAsynchronouslyWithCompletionHandler {
                postHandler(success: true)
                print("EXPORTED..try to play it now")
            }
        }
    }
    
    
}


