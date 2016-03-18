//
//  SongMix.swift
//  MiniMix
//
//  Created by Jeff Newell on 2/17/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import CoreData

class SongMix: NSManagedObject {
    struct Keys {
        static let ID = "song_identifier_hash"
        static let Name = "name"
        static let Genre = "genre"
        static let SongDescription = "song_description"
        static let SelfRating = "self_rating"
        static let CommunityRatingAvg = "community_rating"
        static let UserDidSetSongInfo = "user_initialized_flag"
        static let SongDurationSeconds = "song_duration_secs"
        static let CreatedAt = "created_at"
        static let UpdatedAt = "updated_at"
        static let MixFileRemoteUrl = "mix_file_url"
        static let S3RandomId = "s3_random_id"
    }
    static let UNCHARACTERIZED_GENRE = "Uncharacterized"
    static let genres = [ "Country", "Classical", "Rock", "Folk", "Jazz", "Alternative", "Metal", UNCHARACTERIZED_GENRE]
    
    @NSManaged var id: String //NSUUID
    @NSManaged var name: String
    @NSManaged var createDate: NSDate
    @NSManaged var genre: String
    @NSManaged var userInitialized: Bool //did the user make edits or is this just the default values
    @NSManaged var songDescription: String?
    @NSManaged var lengthInSeconds: NSNumber? //Double?
    @NSManaged var rating: NSNumber? //Float?
    @NSManaged var lastEditDate: NSDate?
    @NSManaged var s3RandomId: String?
    @NSManaged var mixFileUrl: String?
    //relationships
    @NSManaged var tracks: [AudioTrack]
    @NSManaged var artist: User?
    
    var wasUploaded: Bool {
        return mixFileUrl != nil && s3RandomId != nil
    }
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(jsonDictionary dictionary: [String: AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("SongMix", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        id = dictionary[SongMix.Keys.ID] as! String
        name = dictionary[SongMix.Keys.Name] as! String
        createDate = dictionary[SongMix.Keys.CreatedAt] as! NSDate
        genre = dictionary[SongMix.Keys.Genre] as! String
        userInitialized = dictionary[SongMix.Keys.UserDidSetSongInfo] as! Bool
        songDescription = dictionary[SongMix.Keys.SongDescription] as? String
        lengthInSeconds = dictionary[SongMix.Keys.SongDurationSeconds] as? Double
        rating = dictionary[SongMix.Keys.SelfRating] as? Float
        lastEditDate = dictionary[SongMix.Keys.UpdatedAt] as? NSDate
        mixFileUrl = dictionary[SongMix.Keys.MixFileRemoteUrl] as? String
        s3RandomId = dictionary[SongMix.Keys.S3RandomId] as? String
    }

    init(songName: String, insertIntoManagedObjectContext context: NSManagedObjectContext){
        let entity = NSEntityDescription.entityForName("SongMix", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        //defaults
        id = NSUUID().UUIDString
        createDate = NSDate()
        genre = SongMix.UNCHARACTERIZED_GENRE
        userInitialized = false
        //
        name = songName
    }
    
    
//    init(songName: String) {
//        name = songName
//        createDate = NSDate()
//        id = NSUUID().UUIDString
//        genre = "Uncharacterized"
//        userInitialized = false
//        tracks = [AudioTrack]()
//    }
    
    // TODO: this will be avaible once you CoreData-ize this, use it to manage the audio file deletions..
//    override func prepareForDeletion() {
//        FlickrProvider.Caches.imageCache.deleteImageFile(withIdentifier: photoId)
//    }
    
    
//    func deleteTracks() {
//        //TODO: fold this into the proper place after all the CoreData and Cache infrastructure is set up, will want a cascade delete on the relationship
//        // so that'w what probably takes care of this...put the prepareForDeletion on the AudioTrack object to delete that file
//        
//        for track in tracks {
//            try! NSFileManager.defaultManager().removeItemAtPath(AudioCache.trackPath(track, parentSong: self).path!)
//        }
//        tracks.removeAll()
//    }
    
    override func prepareForDeletion() {
        for track in tracks {
            print("Deleting track: \(track.name)....")
            do {
                try NSFileManager.defaultManager().removeItemAtPath(AudioCache.trackPath(track, parentSong: self).path!)
            } catch let deleteTrackErr as NSError {
                print("Failed to delete track file: \(deleteTrackErr)")
            }
        }
    }
}
