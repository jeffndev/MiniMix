//
//  AudioCache.swift
//  MiniMix
//
//  Created by Jeff Newell on 3/1/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

//TODO: rework this to deal with 
import Foundation
import UIKit

class AudioCache {
    
    private var inMemoryCache = NSCache()
    
    // MARK: - Retreiving images
    
    func imageWithIdentifier(identifier: String?) -> UIImage? {
        
        // If the identifier is nil, or empty, return nil
        if identifier == nil || identifier! == "" {
            return nil
        }
        
        let path = pathForIdentifier(identifier!)
        
        // First try the memory cache
        if let image = inMemoryCache.objectForKey(identifier!) as? UIImage {
            return image
        }
        
        // Next Try the hard drive
        if let data = NSData(contentsOfFile: path) {
            return UIImage(data: data)
        }
        
        return nil
    }
    
    //MARK: - deleting images
    func deleteImageFile(withIdentifier identifier: String) {
        let path = pathForIdentifier(identifier)
        inMemoryCache.removeObjectForKey(identifier)
        do {
            try NSFileManager.defaultManager().removeItemAtPath(path)
        }catch let error as NSError {
            if NSFileManager.defaultManager().fileExistsAtPath(path) {
                print("could not remove existing image file: \(path): \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Saving images
    
    func storeImage(image: UIImage?, withIdentifier identifier: String) {
        let path = pathForIdentifier(identifier)
        
        // If the image is nil, remove images from the cache
        if image == nil {
            inMemoryCache.removeObjectForKey(identifier)
            
            do {
                try NSFileManager.defaultManager().removeItemAtPath(path)
            } catch _ {}
        }
        
        // Otherwise, keep the image in memory
        inMemoryCache.setObject(image!, forKey: identifier)
        
        // And in documents directory
        let data = UIImagePNGRepresentation(image!)!
        data.writeToFile(path, atomically: true)
    }
    
    // MARK: - Helper
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
    
    func pathForIdentifier(identifier: String) -> String {
        var mutableIdentifier = identifier
        if !identifier.hasSuffix(".jpg") {
            mutableIdentifier = "\(identifier).jpg"
        }
        let documentsDirectoryURL: NSURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
        let fullURL = documentsDirectoryURL.URLByAppendingPathComponent(mutableIdentifier)
        
        return fullURL.path!
    }
}