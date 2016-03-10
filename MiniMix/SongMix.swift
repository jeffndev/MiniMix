//
//  SongMix.swift
//  MiniMix
//
//  Created by Jeff Newell on 2/17/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import UIKit
import AVFoundation

class SongMix: NSObject {
    
    static let genres = [ "Country", "Classical", "Rock", "Folk", "Jazz", "Alternative", "Metal", "Uncharacterized"]
    
    var id: NSUUID
    var name: String
    var createDate: NSDate
    var genre: String
    //var numberOfTracks: Int?
    var songDescription: String?
    var lengthInSeconds: Double?
    var rating: Float?
    var lastEditDate: NSDate?
    var tracks: [AudioTrack]
    var userInitialized: Bool
    
    init(songName: String) {
        name = songName
        createDate = NSDate()
        id = NSUUID()
        genre = "Uncharacterized"
        userInitialized = false
        tracks = [AudioTrack]()
    }
    
    // TODO: this will be avaible once you CoreData-ize this, use it to manage the audio file deletions..
//    override func prepareForDeletion() {
//        FlickrProvider.Caches.imageCache.deleteImageFile(withIdentifier: photoId)
//    }
    
    
    func deleteTracks() {
        //TODO: fold this into the proper place after all the CoreData and Cache infrastructure is set up, will want a cascade delete on the relationship
        // so that'w what probably takes care of this...put the prepareForDeletion on the AudioTrack object to delete that file
        
        for track in tracks {
            try! NSFileManager.defaultManager().removeItemAtPath(AudioCache.trackPath(track, parentSong: self).path!)
        }
        tracks.removeAll()
    }
}
