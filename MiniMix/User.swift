//
//  User.swift
//  MiniMix
//
//  Created by Jeff Newell on 3/10/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import CoreData

class User: NSManagedObject {
    struct Keys {
        static let Email = "email"
        static let Password = "password"
        static let SocialName = "display_name"
        static let IsRegistered = "registered_flag"
    }
    
    @NSManaged var email: String
    @NSManaged var servicePassword: String
    @NSManaged var socialName: String
    @NSManaged var isRegistered: Bool
    @NSManaged var isMe: Bool
    @NSManaged var songs: [SongMix]
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(jsonDictionary dictionary: [String: AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("User", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        email = dictionary[User.Keys.Email] as! String
        servicePassword = dictionary[User.Keys.Password] as! String
        socialName = dictionary[User.Keys.SocialName] as! String
        isRegistered = dictionary[User.Keys.IsRegistered] as! Bool
    }
    
    init(thisIsMe: Bool, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("User", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        email = ""
        servicePassword = ""
        socialName = ""
        isRegistered = false
        isMe = true
    }
    
    init(thisIsMe: Bool, userEmail: String, userPwd: String, displayName: String, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("User", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        email = userEmail
        servicePassword = userPwd
        socialName = displayName
        isRegistered = true
        isMe = thisIsMe
    }

}
