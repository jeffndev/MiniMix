//
//  MiniMixCommunityAPI.swift
//  MiniMix
//
//  Created by Jeff Newell on 3/11/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import Foundation


class MiniMixCommunityAPI {
    struct ErrorCodes {
        static let NETWORK_ERROR = 400
        static let API_ERROR = 100 //TODO: decide on proper list of error codes to send along, add to this
    }
    let API_AUTH_NAME = "MixPublicUser"
    let API_AUTH_PASSWORD = "7nGU86iI5FCKZJ1Az0R2E7CGZOx2E1A6lJ9i7aD7UPkXDPE3OetAGzHE75T118Ri"
    let API_BASE_URL_SECURE = "http://jnhomesvrnn:3000/api"
    
    
    
    func registerNewUser(email: String, password: String, publicName: String, completion: ((success: Bool, message: String?, error: NSError?) -> Void)?) {
        //would need the users email
        let builtUrlString = "\(API_BASE_URL_SECURE)/register_user"
        let url = NSURL(string: builtUrlString)!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        //print(request.URL)
        //print(url.port)
        //add headers
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let basicAuthString = "\(API_AUTH_NAME):\(API_AUTH_PASSWORD)"
        let utf8str = basicAuthString.dataUsingEncoding(NSUTF8StringEncoding)
        let base64EncodedString = utf8str?.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
        request.addValue("Basic \(base64EncodedString!)", forHTTPHeaderField: "Authorization")

        //add body
        //TODO: encrypt the password..
        let encrypted_password = password
        request.HTTPBody = "{\"display_name\":\"\(publicName)\",\"email\":\"\(email)\",\"password\":\"\(encrypted_password)\"}".dataUsingEncoding(NSUTF8StringEncoding)
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(request) { data, response, error in
            //Do stuff...
            
            guard let data = data else {
                completion!(success: false, message: "data from JSON request came up empty", error: error)
                return
            }
            var parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch let jsonErr as NSError {
                print("ooops register_user failed on http return: \(jsonErr)")
                completion!(success: false, message: "signup failed to return parseable json", error: nil)
                return
            }
            print(parsedResult)
            guard let jsonDictionary = parsedResult as? [String: AnyObject] else {
                completion!(success: false, message: "signup failed to return parseable json", error: nil)
                return
            }
            let tokensOK = self.handleLocalAuthTokenData(jsonDictionary)
            completion!(success: tokensOK, message: tokensOK ? nil : "Could not identify user credentials from registration", error: nil)
        }
        task.resume()
    }
    
    func signin(email: String, password: String, publicName: String, completion: ((success: Bool, message: String?, error: NSError?) -> Void)?) {
        let builtUrlString = "\(API_BASE_URL_SECURE)/signin"
        let url = NSURL(string: builtUrlString)!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        //print(request.URL)
        //print(url.port)
        //add headers
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")//WARNING: CONTENT TYPE: code repeats, need to pull to function..
        let basicAuthString = "\(API_AUTH_NAME):\(API_AUTH_PASSWORD)"
        let utf8str = basicAuthString.dataUsingEncoding(NSUTF8StringEncoding)
        let base64EncodedString = utf8str?.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
        request.addValue("Basic \(base64EncodedString!)", forHTTPHeaderField: "Authorization") //WARNING: AUTHORIZATION HDR: code repeats, need to pull to function..
        
        //add body
        //TODO: encrypt the password..
        let encrypted_password = password
        request.HTTPBody = "{\"email\":\"\(email)\",\"password\":\"\(encrypted_password)\"}".dataUsingEncoding(NSUTF8StringEncoding)
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(request) { data, response, error in
            //Do stuff...
            
            guard let data = data else {
                completion!(success: false, message: "data from JSON request came up empty", error: error)
                return
            }
            var parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch let jsonErr as NSError {
                print("ooops signin failed on http return: \(jsonErr)")
                completion!(success: false, message: "signup failed to return parseable json", error: nil)
                return
            }
            print(parsedResult)
            guard let jsonDictionary = parsedResult as? [String: AnyObject] else {
                completion!(success: false, message: "signup failed to return parseable json", error: nil)
                return
            }
            let tokensOK = self.handleLocalAuthTokenData(jsonDictionary)
            completion!(success: tokensOK, message: tokensOK ? nil : "Could not identify user credentials from signin", error: nil)
        }
        task.resume()
    }
    
    func uploadSong(email: String, password: String, song: SongMix, completion: ((success: Bool, message: String?, error: NSError?) -> Void)?) {
        //first check that the song mix actually happened...
        if !NSFileManager.defaultManager().fileExistsAtPath(AudioCache.mixedSongPath(song).path!) {
            AudioHelpers.createSongMixFile(song) { success in
                if !success {
                    completion!(success: success, message: "Unable to create track mix file", error: nil)
                    return
                }
            }
        }
        //TODO: I think you need to separate the Request...
        //  first: send the song and track info in a more typical format, the json format....
        // Then, as a post-handler on that, send each audio file..with it's user email, song id and track id
        //create the multi-part request
        let boundary = "---------------------------14737809831466499882746641449"
        let builtUrlString = "\(API_BASE_URL_SECURE)/upload_song"
        let url = NSURL(string: builtUrlString)!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        //HTTP HEADERS...
        let contentTypeHdr = "multipart/form-data; boundary=\(boundary)"
        request.addValue(contentTypeHdr, forHTTPHeaderField: "Content-Type") //WARNING: CONTENT TYPE: code repeats, need to pull to function..
        let basicAuthString = "\(API_AUTH_NAME):\(API_AUTH_PASSWORD)"
        let utf8str = basicAuthString.dataUsingEncoding(NSUTF8StringEncoding)
        let base64EncodedString = utf8str?.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
        request.addValue("Basic \(base64EncodedString!)", forHTTPHeaderField: "Authorization")//WARNING: AUTHORIZATION HDR: code repeats, need to pull to function..
        //HTTP Body..
        request.HTTPBody = mixFileUploadPayload(email, song: song, htmlMultipartFormBoundary: boundary)
        //GOT REQUEST....
        let session = NSURLSession.sharedSession()
        let songTask = session.dataTaskWithRequest(request) { data, response, error in
            //Do stuff...
            
            guard let data = data else {
                completion!(success: false, message: "data from JSON request came up empty", error: error)
                return
            }
            var parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch let jsonErr as NSError {
                print("ooops signin failed on http return: \(jsonErr)")
                completion!(success: false, message: "signup failed to return parseable json", error: nil)
                return
            }
            print(parsedResult)
            guard let _ = parsedResult as? [String: AnyObject] else {
                completion!(success: false, message: "signup failed to return parseable json", error: nil)
                return
            }
            completion!(success: true, message: nil, error: nil)
        }
        songTask.resume()
    }
    
    //MARK: Private helpers...
    private func handleLocalAuthTokenData(jsonDictionary: [String: AnyObject]) -> Bool {
        guard let api_token = jsonDictionary["api_authtoken"] as? String else {
            print("could not retrieve signin token and expiration from API")
            return false
        }
        guard let str_authtoken_expiry = jsonDictionary["authtoken_expiry"] as? String else {
            print("could not get expiry data: \(jsonDictionary["authtoken_expiry"])")
            return false
        }
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        guard let authtoken_expiry = dateFormatter.dateFromString(str_authtoken_expiry) else {
            print("could not interpret expiry date")
            return false
        }
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setBool(true, forKey: "MIX_API_LOGGED_IN_FLAG")
        defaults.setObject(api_token, forKey: "MIX_API_LOGGIN_TOKEN") //TODO: maybe should put these in keychain instead of user defaults
        defaults.setObject(authtoken_expiry, forKey: "MIX_API_LOGIN_EXPIRY") //..
        return true
    }
    
    func addFormData(boundary: String, name: String, theData: AnyObject) -> NSData {
        let data = NSMutableData()
        let boundaryString = "--\(boundary)\r\n"
        let closignString = "\r\n"
        
        data.appendData(boundaryString.dataUsingEncoding(NSUTF8StringEncoding)!)
        data.appendData("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
        data.appendData(theData.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
        data.appendData(closignString.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
        return data
    }
    func addFormAttachmentData(boundary: String, name: String, attachmentFilename: String, theData: NSData) -> NSData {
        let data = NSMutableData()
        let boundaryString = "--\(boundary)\r\n"
        let closignString = "\r\n"
        
        data.appendData(boundaryString.dataUsingEncoding(NSUTF8StringEncoding)!)
        data.appendData("Content-Disposition: attachment; name=\"\(name)\"; filename=\"\(attachmentFilename)\"\r\n".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
        data.appendData("Content-Type: application/octet-stream\r\n\r\n".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
        data.appendData(theData)
        data.appendData(closignString.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
        return data
    }
    
    func mixFileUploadPayload(userEmail: String, song: SongMix, htmlMultipartFormBoundary boundary: String) -> NSMutableData {
        let dataPiecesForBody = NSMutableData()
        
        
        dataPiecesForBody.appendData(addFormData(boundary, name: User.Keys.Email, theData: userEmail))
        dataPiecesForBody.appendData(addFormAttachmentData(boundary, name: "mix", attachmentFilename: "mixfile", theData: AudioCache.mixedSongAsData(song)))
        dataPiecesForBody.appendData(addFormData(boundary, name: SongMix.Keys.ID, theData: song.id))
        dataPiecesForBody.appendData(addFormData(boundary, name: SongMix.Keys.Name, theData: song.name))
        dataPiecesForBody.appendData(addFormData(boundary, name: SongMix.Keys.Genre, theData: song.genre))
        //song_id
        //song_name
        //song_genre
        
        
        
        dataPiecesForBody.appendData("--\(boundary)--\r\n".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
        return dataPiecesForBody
        
//        
//        let boundaryString = "--\(boundary)\r\n"
//        
//        let closignString = "\r\n"
//        let boundaryData0 = boundaryString.dataUsingEncoding(NSUTF8StringEncoding) as NSData!
//        //HEAD PIECE
//        dataPiecesForBody.appendData(boundaryData0)
//        let formData_userEmail_meta = "Content-Disposition: form-data; name=\"email\"\r\n\r\n".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
//        dataPiecesForBody.appendData(formData_userEmail_meta!)
//        let formData_userEmail = userEmail.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
//        dataPiecesForBody.appendData(formData_userEmail!)
//        dataPiecesForBody.appendData(closignString.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
//        dataPiecesForBody.appendData(boundaryString.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
//        //MIX FILE PIECE
//        //-----------------------------------
//        //parameter name
//        let mixFileMetaData = "Content-Disposition: attachment; name=\"mix\"; filename=\"mixfile.m4a\"\r\n".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
//        dataPiecesForBody.appendData(mixFileMetaData!)
//        //content type
//        let mixfileContentType = "Content-Type: application/octet-stream\r\n\r\n".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
//        dataPiecesForBody.appendData(mixfileContentType!)
//        //audio file data
//        dataPiecesForBody.appendData(AudioCache.mixedSongAsData(song))
//        //end line
//        let mixfileDataEnding = "\r\n".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
//        dataPiecesForBody.appendData(mixfileDataEnding!)
//        //boundary
//        let boundaryData2 = boundaryString.dataUsingEncoding(NSUTF8StringEncoding) as NSData!
//        dataPiecesForBody.appendData(boundaryData2)
//        //MIX FILE META DATA as Form Data
//        //---------------------------------------
//        // ID of the song
//        let mixFormData_ID_meta = "Content-Disposition: form-data; name=\"song_id\"\r\n\r\n".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
//        dataPiecesForBody.appendData(mixFormData_ID_meta!)
//        let mixFormData_ID = song.id.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
//        dataPiecesForBody.appendData(mixFormData_ID!)
//        let mix_ID_closing = "\r\n".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
//        dataPiecesForBody.appendData(mix_ID_closing!)
//        let boundaryData3 = boundaryString.dataUsingEncoding(NSUTF8StringEncoding) as NSData!
//        dataPiecesForBody.appendData(boundaryData3)
//        // name of the song
//        let mixFormData_songname_meta = "Content-Disposition: form-data; name=\"song_name\"\r\n\r\n".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
//        dataPiecesForBody.appendData(mixFormData_songname_meta!)
//        let mixFormData_name = song.name.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
//        dataPiecesForBody.appendData(mixFormData_name!)
//        let mix_name_closing = "\r\n".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
//        dataPiecesForBody.appendData(mix_name_closing!)
//        let boundaryData4 = boundaryString.dataUsingEncoding(NSUTF8StringEncoding) as NSData!
//        dataPiecesForBody.appendData(boundaryData4)
//        // genre of the song
//        let mixFormData_genre_meta = "Content-Disposition: form-data; name=\"genre\"\r\n\r\n".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
//        dataPiecesForBody.appendData(mixFormData_genre_meta!)
//        let mixFormData_genre = song.genre.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
//        dataPiecesForBody.appendData(mixFormData_genre!)
//        let mix_genre_closing = "\r\n".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
//        dataPiecesForBody.appendData(mix_genre_closing!)
//        
//        //let boundaryData5 = boundaryString.dataUsingEncoding(NSUTF8StringEncoding) as NSData!
//        //dataPiecesForBody.appendData(boundaryData5)
//        // description of the song
//        
//        // self rating of the song
//        
//        // song duration in seconds
//        
//        // last update (updated_at)
//        //....END SONG MIX DATA....
//        
//        //...TRACKS..........
//        for track in song.tracks {
//            //TRACK AUDIO FILE....
//            print(track.name)
//            //TRACK META DATA as Form Data..
//        }
//        let closingData = "--\(boundary)--\r\n"
//        let boundaryDataEnd = closingData.dataUsingEncoding(NSUTF8StringEncoding) as NSData!
//        
//        dataPiecesForBody.appendData(boundaryDataEnd)
//        return dataPiecesForBody
    }
}