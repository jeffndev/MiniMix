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
        static let ID = "track_identifier_hash"
        static let Name = "name"
        static let CreatedAt = "created_at"
        static let TrackType = "mix_or_track" //TODO: this may go away..not needed
        static let TrackDescription = "track_description"
        static let DurationSeconds = "track_duration_secs"
        static let MixVolume = "mix_volume"
        static let HasRecordedFile = "has_audio_file"
        static let TrackDisplayOrder = "display_order"
        static let TrackFileRemoteUrl = "track_file_url"
        static let S3RandomId = "s3_random_id"
    }
    //TODO: may not be neded, since the song is not really a Track,
    //   and the actual files are stored separately..
    struct TrackType {
        static let MIX = "mix"
        static let MASTER = "master"
    }
    
    @NSManaged var id: String//NSUUID
    @NSManaged var name: String
    @NSManaged var createDate: NSDate
    //@NSManaged var trackType: String //TrackType
    @NSManaged var displayOrder: Int32
    @NSManaged var trackDescription: String?
    @NSManaged var lengthSeconds: NSNumber? //Double?
    @NSManaged var mixVolume: NSNumber //Float
    @NSManaged var hasRecordedFile: Bool
    @NSManaged var song: SongMix?
    @NSManaged var trackFileUrl: String?
    @NSManaged var s3RandomId: String?
    var isMuted = false //non-persistant

    var wasUploaded: Bool {
        return trackFileUrl != nil && s3RandomId != nil
    }
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String: AnyObject], context: NSManagedObjectContext){
        let entity = NSEntityDescription.entityForName("AudioTrack", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        id = dictionary[AudioTrack.Keys.ID] as! String
        name = (dictionary[AudioTrack.Keys.Name] as? String) ?? ""
        //Date from string...
        if let strCreateDate = dictionary[AudioTrack.Keys.CreatedAt] as? String where !strCreateDate.isEmpty {
            let dateFormater = NSDateFormatter()
            dateFormater.dateFormat =  MiniMixCommunityAPI.JSON_DATE_FORMAT_STRING // "yyyy-MM-dd'T'HH:mm:ssZ"
            if let parsedDate = dateFormater.dateFromString(strCreateDate) {
                createDate = parsedDate
            } else {
                createDate = NSDate()
            }
        } else {
            createDate = NSDate()
        }

        //trackType = TrackType.MIX //  dictionary[AudioTrack.Keys.TrackType] as! String TODO: this is not needed any more remove..
        trackDescription = dictionary[AudioTrack.Keys.TrackDescription] as? String
        lengthSeconds = dictionary[AudioTrack.Keys.DurationSeconds] as? Double
        mixVolume = dictionary[AudioTrack.Keys.MixVolume] as! Float
        hasRecordedFile = (dictionary[AudioTrack.Keys.HasRecordedFile] as? Bool) ?? true
        print( dictionary[AudioTrack.Keys.TrackDisplayOrder] )
        displayOrder = Int32(dictionary[AudioTrack.Keys.TrackDisplayOrder] as! Int)
        trackFileUrl = dictionary[AudioTrack.Keys.TrackFileRemoteUrl] as? String
        s3RandomId = dictionary[AudioTrack.Keys.S3RandomId] as? String
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
        //self.trackType = (trackType == TrackType.MIX ? TrackType.MIX : TrackType.MASTER)
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
}
