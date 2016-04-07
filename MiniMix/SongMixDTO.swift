//
//  SongMixLite.swift
//  MiniMix
//
//  Created by Jeff Newell on 3/22/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import Foundation

struct SongMixDTO { //See DTO pattern Data Transfer Object attributed to Martin Fowler: Patterns of Enterprise Software 
    
    //SongInfo
    var id: String //NSUUID
    var name: String
    var createDate: NSDate
    var genre: String
    var userInitialized: Bool //did the user make edits or is this just the default values
    var songDescription: String?
    var lengthInSeconds: NSNumber? //Double?
    var rating: NSNumber? //Float?
    var s3RandomId: String?
    var mixFileUrl: String?
    var keepPrivate: Bool
    var userDisplayName: String
    var version: NSNumber //INT
    
    var tracks: [AudioTrackDTO]?
    
    var wasUploaded: Bool {
        return mixFileUrl != nil
    }
    
    init(jsonDictionary dictionary: [String: AnyObject]) {
        id = dictionary[SongMix.Keys.ID] as! String
        name = (dictionary[SongMix.Keys.Name] as? String) ?? ""
        //Date from string...
        let strCreateDate = dictionary[SongMix.Keys.CreatedAt] as! String
        let dateFormater = NSDateFormatter()
        dateFormater.dateFormat = MiniMixCommunityAPI.JSON_DATE_FORMAT_STRING //  "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        createDate = dateFormater.dateFromString(strCreateDate) ?? NSDate()
        
        genre = dictionary[SongMix.Keys.Genre] as! String
        userInitialized = true
        songDescription = dictionary[SongMix.Keys.SongDescription] as? String
        lengthInSeconds = 0
        rating = dictionary[SongMix.Keys.SelfRating] as? Float

        mixFileUrl = dictionary[SongMix.Keys.MixFileRemoteUrl] as? String
        s3RandomId = dictionary[SongMix.Keys.S3RandomId] as? String
        keepPrivate = (dictionary[SongMix.Keys.PrivacyFlag] as? Bool) ?? false
        userDisplayName = dictionary[User.Keys.SocialName] as! String
        version = (dictionary[SongMix.Keys.VersionNumber] as? Int) ?? 0
    }
    
    init(songObject: SongMix, includeTrackInfo: Bool = false) {
        id = songObject.id
        name = songObject.name
        createDate = songObject.createDate
        genre = songObject.genre
        userInitialized = songObject.userInitialized
        songDescription = songObject.songDescription
        lengthInSeconds = songObject.lengthInSeconds
        rating = songObject.rating
        s3RandomId = songObject.s3RandomId
        mixFileUrl = songObject.mixFileUrl
        keepPrivate = songObject.keepPrivate
        version = songObject.version
        if let artist = songObject.artist {
            userDisplayName = artist.socialName
        } else {
            userDisplayName = ""
        }
        if includeTrackInfo {
            if tracks == nil {
                tracks = [AudioTrackDTO]()
            }
            tracks!.removeAll()
            for t in songObject.tracks {
                tracks!.append(AudioTrackDTO(trackObject: t))
            }
        }
    }
}
