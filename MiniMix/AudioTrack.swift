//
//  AudioTrack.swift
//  MiniMix
//
//  Created by Jeff Newell on 2/17/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import UIKit
import CoreData

class AudioTrack: NSManagedObject {
    struct Keys {
        static let ID = "id"
        static let Name = "name"
        static let CreatedAt = "created_at"
        static let TrackType = "mix_or_track"
        static let TrackDescription = "track_description"
        static let DurationSeconds = "track_duration_secs"
        static let MixVolume = "mix_volume"
        static let HasRecordedFile = "has_audio_file"
        static let TrackDisplayOrder = "display_order"
    }
    struct TrackType {
        static let MIX = "mix"
        static let MASTER = "master"
    }
    
    @NSManaged var id: String//NSUUID
    @NSManaged var name: String
    @NSManaged var createDate: NSDate
    @NSManaged var trackType: String //TrackType
    @NSManaged var displayOrder: Int32
    @NSManaged var trackDescription: String?
    @NSManaged var lengthSeconds: NSNumber? //Double?
    @NSManaged var mixVolume: NSNumber //Float
    @NSManaged var hasRecordedFile: Bool
    @NSManaged var song: SongMix?
    var isMuted = false //non-persistant

    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String: AnyObject], context: NSManagedObjectContext){
        let entity = NSEntityDescription.entityForName("AudioTrack", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        id = dictionary[AudioTrack.Keys.ID] as! String
        name = dictionary[AudioTrack.Keys.Name] as! String
        createDate = dictionary[AudioTrack.Keys.CreatedAt] as! NSDate
        trackType = dictionary[AudioTrack.Keys.TrackType] as! String
        trackDescription = dictionary[AudioTrack.Keys.TrackDescription] as? String
        lengthSeconds = dictionary[AudioTrack.Keys.DurationSeconds] as? Double
        mixVolume = dictionary[AudioTrack.Keys.MixVolume] as! Float
        hasRecordedFile = dictionary[AudioTrack.Keys.HasRecordedFile] as! Bool
        displayOrder = dictionary[AudioTrack.Keys.TrackDisplayOrder] as! Int32
    }
    
    init(trackName: String, trackType: String, trackOrder: Int32, insertIntoManagedObjectContext context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("AudioTrack", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        //defaults
        id = NSUUID().UUIDString
        createDate = NSDate()
        mixVolume = 1.0
        hasRecordedFile = false
        //
        name = trackName
        self.trackType = (trackType == TrackType.MIX ? TrackType.MIX : TrackType.MASTER)
        displayOrder = trackOrder
    }
    
    override func prepareForDeletion() {
        super.prepareForDeletion()
        print("Deleting track: \(name)....")
        //IT seems that the song object gets killed first, before the cascade deletes do the tracks
        //  SO, the only time this will work will be when the Song is still alive..ie deleting a track in Mix View
        //  The Full deletion of the Song and the cascading takes care of deleting the track audio files, so got it covered both ways
        guard let parentSong = song else {
            print("parent song id was nil for this track")
            return
        }
        do {
            try NSFileManager.defaultManager().removeItemAtPath(AudioCache.trackPath(self, parentSong: parentSong).path!)
        } catch let deleteTrackErr as NSError {
            print("Failed to delete track file: \(deleteTrackErr)")
        }
    }
    
//    init(trackName: String, type: TrackType, trackDescription: String?) {
//        name = trackName
//        self.trackDescription = trackDescription
//        trackType = type
//        createDate = NSDate()
//        id = NSUUID().UUIDString
//        mixVolume = 1.0
//        hasRecordedFile = false
//    }
}
