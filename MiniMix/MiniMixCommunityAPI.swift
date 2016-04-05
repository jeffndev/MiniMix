//
//  MiniMixCommunityAPI.swift
//  MiniMix
//
//  Created by Jeff Newell on 3/11/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import Foundation

class MiniMixCommunityAPI {
    typealias DataCompletionHander = ((success: Bool, jsonData: [String: AnyObject]?, message: String?, error: NSError?) -> Void)?
    typealias BoolCompletionHander = ((success: Bool, istrue: Bool?, message: String?, error: NSError?) -> Void)?
    typealias DataArrayCompletionHander = ((success: Bool, jsonData: [[String: AnyObject]]?, message: String?, error: NSError?) -> Void)?
    typealias CompletionHander = ((success: Bool, message: String?, error: NSError?) -> Void)?
    
    struct ErrorCodes {
        static let NETWORK_ERROR = 400
        static let API_ERROR = 100
    }
    enum HTTPRequestAuthType {
        case HTTPBasicAuth
        case HTTPTokenAuth
    }
    
    enum HTTPRequestContentType {
        case HTTPJsonContent
        case HTTPMultipartContent
    }
    let API_AUTH_NAME = "MixPublicUser"
    let API_AUTH_PASSWORD = "7nGU86iI5FCKZJ1Az0R2E7CGZOx2E1A6lJ9i7aD7UPkXDPE3OetAGzHE75T118Ri"
    let API_BASE_URL_SECURE = "https://minimixsocial.herokuapp.com/api" //"http://jnhomesvrnn:3000/api"//

    let httpRequestBoundary = "---------------------------14737809831466499882746641449"
    static let JSON_DATE_FORMAT_STRING = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    
    private let DEFAULTS_KEY_API_TOKEN = "MIX_API_LOGGIN_TOKEN" //TODO: maybe should put these in keychain instead of user defaults, version 2.0
    private let DEFAULTS_KEY_API_EXPIRY = "MIX_API_LOGIN_EXPIRY"
    
    //MARK: PUBLIC API interface..
    func registerNewUser(email: String, password: String, publicName: String, completion: DataCompletionHander) {
        let builtUrlString = "\(API_BASE_URL_SECURE)/register_user"
        let url = NSURL(string: builtUrlString)!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        //add headers
        request.addValue( buildContentTypeHdr(.HTTPJsonContent), forHTTPHeaderField: "Content-Type" )
        request.addValue( buildAuthorizationHdr(.HTTPBasicAuth), forHTTPHeaderField: "Authorization" )

        let encrypted_password = AESCrypt.encrypt(password, password: API_AUTH_PASSWORD)
        //add body
        request.HTTPBody = "{\"display_name\":\"\(publicName)\",\"email\":\"\(email)\",\"password\":\"\(encrypted_password)\"}".dataUsingEncoding(NSUTF8StringEncoding)
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(request) { data, response, error in
            guard error == nil else {
                completion!(success: false, jsonData: nil, message: "error recevied from data task", error: error)
                return
            }
            guard let data = data else {
                completion!(success: false, jsonData: nil, message: "data from JSON request came up empty", error: error)
                return
            }
            var parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch let jsonErr as NSError {
                print("ooops register_user failed on http return: \(jsonErr)")
                completion!(success: false, jsonData: nil, message: "signup failed to return parseable json", error: nil)
                return
            }
            print(parsedResult)
            guard let jsonDictionary = parsedResult as? [String: AnyObject] else {
                completion!(success: false, jsonData: nil, message: "signup failed to return parseable json", error: nil)
                return
            }
            
            if let statIndex = jsonDictionary.indexForKey("status") {
                print("status seems to be there??:\(jsonDictionary[statIndex])")
                if let apiStatus = jsonDictionary["status"] as? Int {
                    if apiStatus < 200 || apiStatus >= 300 {
                        completion!(success: false, jsonData: nil, message: jsonDictionary["message"] as? String, error: NSError(domain: "api error", code: MiniMixCommunityAPI.ErrorCodes.API_ERROR, userInfo: nil))
                        return
                    }
                }
            }
            guard let receivedDisplayName = jsonDictionary[User.Keys.SocialName] as? String where !receivedDisplayName.isEmpty,
                let receivedEmailConfirmation = jsonDictionary[User.Keys.Email] as? String where receivedEmailConfirmation == email  else {
                completion!(success: false, jsonData: nil, message: "User was not succesfully registered with MiniMix, please try again later", error: nil)
                return
            }
            guard self.handleLocalAuthTokenData(jsonDictionary) else {
                completion!(success: false, jsonData: nil, message: "Could not find authorization token after signup", error: nil)
                return
            }
            completion!(success: true, jsonData: jsonDictionary, message: nil, error: nil)
        }
        task.resume()
    }
    
    func songCloudVersionOutOfDateCheck(song: SongMix, completion: BoolCompletionHander) {
        let builtUrlString = "\(API_BASE_URL_SECURE)/song_version" + escapedParameters(["song_id": song.id])
        let url = NSURL(string: builtUrlString)!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "GET"
        //add headers
        request.addValue( buildAuthorizationHdr(.HTTPTokenAuth), forHTTPHeaderField: "Authorization")
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(request) { data, response, error in
            guard error == nil else {
                completion!(success: false, istrue: nil, message: "error recevied from song version check task", error: error)
                return
            }
            guard let data = data else {
                completion!(success: false, istrue: nil, message: "data from JSON request came up empty", error: error)
                return
            }
            var parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch let jsonErr as NSError {
                print("verify_token http return: \(jsonErr)")
                completion!(success: false, istrue: nil, message: "song version check failed to return parseable json", error: nil)
                return
            }
            print(parsedResult)
            guard let jsonDictionary = parsedResult as? [String: AnyObject] else {
                completion!(success: false, istrue: nil, message: "song version check failed to return parseable json", error: nil)
                return
            }
            guard let songInfo = jsonDictionary["song_info"] as? [String: AnyObject] else {
                completion!(success: false, istrue: nil, message: "song version check failed to return parseable json", error: nil)
                return
            }
            guard let version = songInfo["version"] as? Int else {
                completion!(success: false, istrue: nil, message: "song version check failed to return parseable json", error: nil)
                return
            }
            completion!(success: true, istrue: version < Int(song.version), message: nil, error: nil)
        }
        task.resume()
    }
    
    func checkIfSongIsPrivate(song: SongMix, completion: BoolCompletionHander) {
        let builtUrlString = "\(API_BASE_URL_SECURE)/song_privacy" + escapedParameters(["song_id": song.id])
        let url = NSURL(string: builtUrlString)!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "GET"
        //add headers
        request.addValue( buildAuthorizationHdr(.HTTPTokenAuth), forHTTPHeaderField: "Authorization")
        
        //add body
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(request) { data, response, error in
            guard error == nil else {
                completion!(success: false, istrue: nil, message: "error recevied from song privacy check task", error: error)
                return
            }
            guard let data = data else {
                completion!(success: false, istrue: nil, message: "data from JSON request came up empty", error: error)
                return
            }
            var parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch let jsonErr as NSError {
                print("verify_token http return: \(jsonErr)")
                completion!(success: false, istrue: nil, message: "song privacy check failed to return parseable json", error: nil)
                return
            }
            print(parsedResult)
            guard let jsonDictionary = parsedResult as? [String: AnyObject] else {
                completion!(success: false, istrue: nil, message: "song privacy check failed to return parseable json", error: nil)
                return
            }
            guard let songInfo = jsonDictionary["song_info"] as? [String: AnyObject] else {
                completion!(success: false, istrue: nil, message: "song privacy check failed to return parseable json", error: nil)
                return
            }
            guard let isPrivate = songInfo["private_flag"] as? Bool else {
                completion!(success: false, istrue: nil, message: "song privacy check failed to return parseable json", error: nil)
                return
            }
            completion!(success: true, istrue: isPrivate, message: nil, error: nil)
        }
        task.resume()
    }
    
    func verifyToken(completion: BoolCompletionHander) {
        let builtUrlString = "\(API_BASE_URL_SECURE)/verify_token"
        let url = NSURL(string: builtUrlString)!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "GET"
        //add headers
        request.addValue( buildAuthorizationHdr(.HTTPTokenAuth), forHTTPHeaderField: "Authorization")
        
        //add body
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(request) { data, response, error in
            guard error == nil else {
                completion!(success: false, istrue: nil, message: "error recevied from token verify task", error: error)
                return
            }
            guard let data = data else {
                completion!(success: false, istrue: nil, message: "data from JSON request came up empty", error: error)
                return
            }
            var parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch let jsonErr as NSError {
                print("verify_token http return: \(jsonErr)")
                completion!(success: false, istrue: nil, message: "verify_token failed to return parseable json", error: nil)
                return
            }
            print(parsedResult)
            guard let jsonDictionary = parsedResult as? [String: AnyObject] else {
                completion!(success: false, istrue: nil, message: "verify_token failed to return parseable json", error: nil)
                return
            }
            guard let verifyInfo = jsonDictionary["verify_info"] as? [String: AnyObject] else {
                completion!(success: false, istrue: nil, message: "verify_token failed to return parseable json", error: nil)
                return
            }
            guard let valid = verifyInfo["valid"] as? Bool else {
                completion!(success: false, istrue: nil, message: "verify_token failed to return parseable json", error: nil)
                return
            }
            completion!(success: true, istrue: valid, message: nil, error: nil)
        }
        task.resume()
    }
    
    func verifyAuthTokenOrSignin(email: String, password: String, completion: CompletionHander) {
        let defaults = NSUserDefaults.standardUserDefaults()
        let token: String? = defaults.objectForKey(DEFAULTS_KEY_API_TOKEN) as? String
        let expiry: NSDate?  = defaults.objectForKey(DEFAULTS_KEY_API_EXPIRY) as? NSDate
        
        if let token = token, let expiry = expiry where !token.isEmpty && NSDate().compare(expiry) == .OrderedAscending {
            verifyToken() { success, istrue, message, error in
                guard success, let valid = istrue where valid else {
                    self.signin(email, password: password, completion: completion)
                    return
                }
                completion!(success: true, message: nil, error: nil)
            }
        } else {
            signin(email, password: password, completion: completion)
        }
    }
    
    func signin(email: String, password: String, completion: CompletionHander) {
        let builtUrlString = "\(API_BASE_URL_SECURE)/signin"
        let url = NSURL(string: builtUrlString)!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        //add headers
        request.addValue( buildContentTypeHdr(.HTTPJsonContent), forHTTPHeaderField: "Content-Type" )
        request.addValue( buildAuthorizationHdr(.HTTPBasicAuth), forHTTPHeaderField: "Authorization")
        
        //add body
        let encrypted_password = AESCrypt.encrypt(password, password: API_AUTH_PASSWORD)
        request.HTTPBody = "{\"email\":\"\(email)\",\"password\":\"\(encrypted_password)\"}".dataUsingEncoding(NSUTF8StringEncoding)
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(request) { data, response, error in
            guard error == nil else {
                completion!(success: false, message: "error recevied from data task", error: error)
                return
            }
            guard let data = data else {
                completion!(success: false, message: "data from JSON request came up empty", error: error)
                return
            }
            var parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch let jsonErr as NSError {
                completion!(success: false, message: "signup failed to return parseable json)", error: jsonErr)
                return
            }
            //print(parsedResult)
            guard let jsonDictionary = parsedResult as? [String: AnyObject] else {
                completion!(success: false, message: "signup failed to return parseable json", error: nil)
                return
            }
            let tokensOK = self.handleLocalAuthTokenData(jsonDictionary)
            completion!(success: tokensOK, message: tokensOK ? nil : "Could not identify user credentials from signin", error: nil)
        }
        task.resume()
    }
    
    func updateSongInfo(song: SongMix, completion: DataCompletionHander) {
        let builtUrlString = "\(API_BASE_URL_SECURE)/update_song_info"
        let url = NSURL(string: builtUrlString)!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        //HTTP HEADERS...
        request.addValue(buildContentTypeHdr(.HTTPMultipartContent, requestBoundary: httpRequestBoundary), forHTTPHeaderField: "Content-Type")
        request.addValue(buildAuthorizationHdr(.HTTPTokenAuth), forHTTPHeaderField: "Authorization")
        request.HTTPBody = mixFileMetaDataUploadPayload(song, includeTrackInfo: false, htmlMultipartFormBoundary: httpRequestBoundary)
        
        //GOT REQUEST....
        let session = NSURLSession.sharedSession()
        let songTask = session.dataTaskWithRequest(request) { data, response, error in
            guard error == nil else {
                completion!(success: false, jsonData: nil, message: "error recevied from data task", error: error)
                return
            }
            guard let data = data else {
                completion!(success: false, jsonData: nil, message: "data from JSON request came up empty", error: error)
                return
            }
            var parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch let jsonErr as NSError {
                print("\(jsonErr)")
                completion!(success: false, jsonData: nil, message: "song update failed to return parseable json", error: nil)
                return
            }
            //print("uploadSongMeta returned json:")
            //print(parsedResult)
            guard let parsedJson = parsedResult as? [String: AnyObject] else {
                completion!(success: false, jsonData: nil, message: "song update failed to return parseable json", error: nil)
                return
            }
            completion!(success: true, jsonData: parsedJson,  message: nil, error: nil)
        }
        songTask.resume()
    }
    
    func uploadSong(keepPrivate: Bool, song: SongMix, completion: DataCompletionHander) {
        //first check that the song mix actually happened...
        if !NSFileManager.defaultManager().fileExistsAtPath(AudioCache.mixedSongPath(song).path!) {
            AudioHelpers.createSongMixFile(song) { success in
                if !success {
                    completion!(success: success, jsonData: nil, message: "Unable to create track mix file", error: nil)
                } else {
                    self.uploadSongAfterFileCheck(keepPrivate, song: song, completion: completion)
                }
            }
        } else {
            uploadSongAfterFileCheck(keepPrivate, song: song, completion: completion)
        }

        
    }
    func uploadSongAfterFileCheck(keepPrivate: Bool, song: SongMix, completion: DataCompletionHander) {
        uploadSongInfo(keepPrivate, song: song) { success, json, message, error in
            if !success {
                completion!(success: success, jsonData: json, message: message, error: error)
                return
            }
            self.uploadSongMixFile(song) { success, json, message, error in
                completion!(success: success, jsonData: json, message: message, error: error)
            }
        }
    }
    
    func searchSongs(searchString: String, completion: DataArrayCompletionHander) {
        let builtUrlString = "\(API_BASE_URL_SECURE)/search_songs"
        let url = NSURL(string: builtUrlString)!
        let request = NSMutableURLRequest(URL: url)
        //NOTE: a good argument is made that search is appropriate for POST rather then GET..also practically, search strings could be too long for http query string
        // http://stackoverflow.com/questions/4203686/how-can-i-deal-with-http-get-query-string-length-limitations-and-still-want-to-b
        request.HTTPMethod = "POST"
        //HTTP HEADERS...
        request.addValue(buildContentTypeHdr(.HTTPJsonContent, requestBoundary: ""), forHTTPHeaderField: "Content-Type")
        request.addValue(buildAuthorizationHdr(.HTTPTokenAuth), forHTTPHeaderField: "Authorization")
        request.HTTPBody = "{\"query\":\"\(searchString)\"}".dataUsingEncoding(NSUTF8StringEncoding)
        
        let session = NSURLSession.sharedSession()
        let searchTask = session.dataTaskWithRequest(request) { data, response, error in
            guard error == nil else {
                completion!(success: false, jsonData: nil, message: "error recevied from data task", error: error)
                return
            }
            guard let data = data else {
                completion!(success: false, jsonData: nil, message: "data from JSON request came up empty", error: error)
                return
            }
            var parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch let jsonErr as NSError {
                completion!(success: false, jsonData: nil, message: "search failed to return parseable json", error: jsonErr)
                return
            }
            //print("uploadSongMeta returned json:")
            //print(parsedResult)
            if let jsonObject = parsedResult as? [String: AnyObject] {
                if let status = jsonObject["status"] as? Int where status > 299 || status < 200 {
                    let msg = (jsonObject["message"] as? String) ?? ""
                    completion!(success: false, jsonData: nil, message: msg, error: nil)
                    return
                }
            }
            guard let parsedJsonArr = parsedResult as? [[String: AnyObject]] else {
                completion!(success: false, jsonData: nil, message: "search failed to return parseable json array", error: nil)
                return
            }
            completion!(success: true, jsonData: parsedJsonArr,  message: nil, error: nil)
        }
        searchTask.resume()

    }
    
    func getMyUploadedSongs(completion: DataArrayCompletionHander) {
        let builtUrlString = "\(API_BASE_URL_SECURE)/my_uploaded_songs"
        let url = NSURL(string: builtUrlString)!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "GET"
        //add headers
        request.addValue( buildAuthorizationHdr(.HTTPTokenAuth), forHTTPHeaderField: "Authorization")
        
        let session = NSURLSession.sharedSession()
        let task = session.dataTaskWithRequest(request) { data, response, error in
            guard error == nil else {
                completion!(success: false, jsonData: nil, message: "error recevied from data task", error: error)
                return
            }
            guard let data = data else {
                completion!(success: false, jsonData: nil, message: "data from JSON request came up empty", error: error)
                return
            }
            var parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch let jsonError as NSError {
                completion!(success: false, jsonData: nil, message: "get my uploaded songs failed to return parseable json", error: jsonError)
                return
            }
            print("getMySongs returned json:")
            print(parsedResult)
            if let jsonObject = parsedResult as? [String: AnyObject] {
                if let status = jsonObject["status"] as? Int where status > 299 || status < 200 {
                    let msg = (jsonObject["message"] as? String) ?? ""
                    completion!(success: false, jsonData: nil, message: msg, error: nil)
                    return
                }
            }
            guard let parsedJsonArr = parsedResult as? [[String: AnyObject]] else {
                completion!(success: false, jsonData: nil, message: "get my uploaded songs failed to return parseable json array", error: nil)
                return
            }
            completion!(success: true, jsonData: parsedJsonArr, message: nil, error: nil)
        }
        task.resume()
    }
    
    //MARK: song upload PIECES...broken down so not one HUGE http request..
    func uploadSongInfo(keepPrivate: Bool, song: SongMix, completion: DataCompletionHander) {
        let builtUrlString = "\(API_BASE_URL_SECURE)/upload_song"
        let url = NSURL(string: builtUrlString)!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        //HTTP HEADERS...
        request.addValue(buildContentTypeHdr(.HTTPMultipartContent, requestBoundary: httpRequestBoundary), forHTTPHeaderField: "Content-Type")
        request.addValue(buildAuthorizationHdr(.HTTPTokenAuth), forHTTPHeaderField: "Authorization")
        request.HTTPBody = mixFileMetaDataUploadPayload(song, includeTrackInfo: true, htmlMultipartFormBoundary: httpRequestBoundary)
        
        //GOT REQUEST....
        let session = NSURLSession.sharedSession()
        let songTask = session.dataTaskWithRequest(request) { data, response, error in
            guard error == nil else {
                completion!(success: false, jsonData: nil, message: "error recevied from data task", error: error)
                return
            }
            guard let data = data else {
                completion!(success: false, jsonData: nil, message: "data from JSON request came up empty", error: error)
                return
            }
            var parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch let jsonErr as NSError {
                completion!(success: false, jsonData: nil, message: "signup failed to return parseable json", error: jsonErr)
                return
            }
            print("uploadSongMeta returned json:")
            print(parsedResult)
            guard let parsedJson = parsedResult as? [String: AnyObject] else {
                completion!(success: false, jsonData: nil, message: "signup failed to return parseable json", error: nil)
                return
            }
            completion!(success: true, jsonData: parsedJson,  message: nil, error: nil)
        }
        songTask.resume()
    }
    
    func uploadSongMixFile(song: SongMix, completion: DataCompletionHander) {
        let builtUrlString = "\(API_BASE_URL_SECURE)/upload_song_file"
        let url = NSURL(string: builtUrlString)!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        //HTTP HEADERS...
        request.addValue(buildContentTypeHdr(.HTTPMultipartContent, requestBoundary: httpRequestBoundary), forHTTPHeaderField: "Content-Type")
        request.addValue(buildAuthorizationHdr(.HTTPTokenAuth), forHTTPHeaderField: "Authorization")
        request.HTTPBody =  mixAudioFilePayload(song, htmlMultipartFormBoundary: httpRequestBoundary)
        
        //GOT REQUEST....
        let session = NSURLSession.sharedSession()
        let songFileTask = session.dataTaskWithRequest(request) { data, response, error in
            guard error == nil else {
                completion!(success: false, jsonData: nil, message: "error recevied from data task", error: error)
                return
            }
            guard let data = data else {
                completion!(success: false, jsonData: nil, message: "data from JSON request came up empty", error: error)
                return
            }
            var parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch let jsonErr as NSError {
                completion!(success: false, jsonData: nil, message: "upload_song_file api failed to return parseable json", error: jsonErr)
                return
            }
            print("uploadSongFile returned json:")
            print(parsedResult)
            guard let parsedJson = parsedResult as? [String: AnyObject] else {
                completion!(success: false, jsonData: nil, message: "upload_song_file api failed to return parseable json", error: nil)
                return
            }
            completion!(success: true, jsonData: parsedJson, message: nil, error: nil)
        }
        songFileTask.resume()
    }
    func uploadTrackFile(track: AudioTrack, completion: DataCompletionHander) {
        let builtUrlString = "\(API_BASE_URL_SECURE)/upload_track_file"
        let url = NSURL(string: builtUrlString)!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        //HTTP HEADERS...
        request.addValue(buildContentTypeHdr(.HTTPMultipartContent, requestBoundary: httpRequestBoundary), forHTTPHeaderField: "Content-Type")
        request.addValue(buildAuthorizationHdr(.HTTPTokenAuth), forHTTPHeaderField: "Authorization")
        request.HTTPBody =  trackAudioFilePayload(track, htmlMultipartFormBoundary: httpRequestBoundary)
        
        //GOT REQUEST....
        let session = NSURLSession.sharedSession()
        let trackFileTask = session.dataTaskWithRequest(request) { data, response, error in
            guard error == nil else {
                completion!(success: false, jsonData: nil, message: "error recevied from data task", error: error)
                return
            }
            guard let data = data else {
                completion!(success: false, jsonData: nil, message: "data from JSON request came up empty", error: error)
                return
            }
            var parsedResult: AnyObject!
            do {
                parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
            } catch let jsonErr as NSError {
                completion!(success: false, jsonData: nil, message: "upload_track_file api failed to return parseable json", error: jsonErr)
                return
            }
            //print("uploadTrackFile returned json:")
            //print(parsedResult)
            guard let parsedJson = parsedResult as? [String: AnyObject] else {
                completion!(success: false, jsonData: nil, message: "upload_track_file api failed to return parseable json", error: nil)
                return
            }
            completion!(success: true, jsonData: parsedJson, message: nil, error: nil)
        }
        trackFileTask.resume()
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
        dateFormatter.dateFormat =  MiniMixCommunityAPI.JSON_DATE_FORMAT_STRING // "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        guard let authtoken_expiry = dateFormatter.dateFromString(str_authtoken_expiry) else {
            print("could not interpret expiry date")
            return false
        }
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setObject(api_token, forKey: DEFAULTS_KEY_API_TOKEN) //TODO: maybe should put these in keychain instead of user defaults
        defaults.setObject(authtoken_expiry, forKey: DEFAULTS_KEY_API_EXPIRY) //..
        return true
    }
    private func buildContentTypeHdr(contentType: HTTPRequestContentType = HTTPRequestContentType.HTTPJsonContent, requestBoundary: String = "") -> String {
        switch contentType {
        case .HTTPJsonContent:
            return "application/json"
        case .HTTPMultipartContent:
            return "multipart/form-data; boundary=\(requestBoundary)"
        }
    }
    private func buildAuthorizationHdr(authorizationType: HTTPRequestAuthType) ->String {
        switch authorizationType {
        case .HTTPBasicAuth:
            let basicAuthString = "\(API_AUTH_NAME):\(API_AUTH_PASSWORD)"
            let utf8str = basicAuthString.dataUsingEncoding(NSUTF8StringEncoding)
            let base64EncodedString = utf8str?.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
            return "Basic \(base64EncodedString!)"
        case .HTTPTokenAuth:
            // TODO: Retreieve Auth_Token from Keychain, version 2.0
            let userToken = getUserAuthToken()  //KeychainAccess.passwordForAccount("Auth_Token", service: "KeyChainService") as String? {
            return "Token token=\(userToken)"
        }
    }
    private func getUserAuthToken() -> String {
        let defaults = NSUserDefaults.standardUserDefaults()
        
        let existingToken =  (defaults.objectForKey(DEFAULTS_KEY_API_TOKEN) as? String) ?? ""
        return existingToken
    }
    
    private func addFormData(boundary: String, name: String, theData: String) -> NSData {
        let data = NSMutableData()
        let boundaryString = "--\(boundary)\r\n"
        let closignString = "\r\n"
        
        data.appendData(boundaryString.dataUsingEncoding(NSUTF8StringEncoding)!)
        data.appendData("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
        data.appendData(theData.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
        data.appendData(closignString.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
        return data
    }
    private func addFormAttachmentData(boundary: String, name: String, attachmentFilename: String, theData: NSData) -> NSData {
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
    
    private func mixFileMetaDataUploadPayload(song: SongMix, includeTrackInfo:Bool, htmlMultipartFormBoundary boundary: String) -> NSMutableData {
        let dataPiecesForBody = NSMutableData()
        
        dataPiecesForBody.appendData(addFormData(boundary, name: SongMix.Keys.PrivacyFlag, theData: "\(song.keepPrivate)"))
        dataPiecesForBody.appendData(addFormData(boundary, name: SongMix.Keys.VersionNumber, theData: "\(song.version)"))
        dataPiecesForBody.appendData(addFormData(boundary, name: SongMix.Keys.ID, theData: song.id))
        dataPiecesForBody.appendData(addFormData(boundary, name: SongMix.Keys.Name, theData: song.name))
        dataPiecesForBody.appendData(addFormData(boundary, name: SongMix.Keys.Genre, theData: song.genre))
        if let self_rate = song.rating as? Float {
            dataPiecesForBody.appendData(addFormData(boundary, name: SongMix.Keys.SelfRating, theData: "\(self_rate)"))
        }
        if let secs_duration = song.lengthInSeconds as? Double {
            dataPiecesForBody.appendData(addFormData(boundary, name: SongMix.Keys.SongDurationSeconds, theData: "\(secs_duration)"))
        }
        if let song_description = song.songDescription {
            dataPiecesForBody.appendData(addFormData(boundary, name: SongMix.Keys.SongDescription, theData: song_description))
        }
        if includeTrackInfo {
            for (index, track) in song.tracks.enumerate() {
                dataPiecesForBody.appendData(addFormData(boundary, name: "\(AudioTrack.Keys.ID)\(index)", theData: track.id))
                dataPiecesForBody.appendData(addFormData(boundary, name: "\(AudioTrack.Keys.Name)\(index)" , theData: track.name))
                dataPiecesForBody.appendData(addFormData(boundary, name: "\(AudioTrack.Keys.TrackDisplayOrder)\(index)", theData: "\(track.displayOrder)"))
                dataPiecesForBody.appendData(addFormData(boundary, name: "\(AudioTrack.Keys.MixVolume)\(index)", theData: "\(track.mixVolume)"))
                if let secs_duration = track.lengthSeconds as? Double {
                    dataPiecesForBody.appendData(addFormData(boundary, name: "\(AudioTrack.Keys.DurationSeconds)\(index)", theData: "\(secs_duration)"))
                }
                if let track_description = track.trackDescription {
                    dataPiecesForBody.appendData(addFormData(boundary, name: "\(AudioTrack.Keys.TrackDescription)\(index)", theData: track_description))
                }
            }
        }
        dataPiecesForBody.appendData("--\(boundary)--\r\n".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
        return dataPiecesForBody
    }
    
    private func mixAudioFilePayload(song: SongMix, htmlMultipartFormBoundary boundary: String) -> NSMutableData {
        let dataPiecesForBody = NSMutableData()
        
        dataPiecesForBody.appendData(addFormData(boundary, name: SongMix.Keys.ID, theData: song.id))
        dataPiecesForBody.appendData(addFormAttachmentData(boundary, name: "mix", attachmentFilename: "mixfile", theData: AudioCache.mixedSongAsData(song)))
        dataPiecesForBody.appendData("--\(boundary)--\r\n".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
        return dataPiecesForBody
    }
    private func trackAudioFilePayload(track: AudioTrack, htmlMultipartFormBoundary boundary: String) -> NSMutableData {
        let dataPiecesForBody = NSMutableData()
        
        dataPiecesForBody.appendData(addFormData(boundary, name: SongMix.Keys.ID, theData: track.song!.id))
        dataPiecesForBody.appendData(addFormData(boundary, name: AudioTrack.Keys.ID, theData: track.id))
        dataPiecesForBody.appendData(addFormAttachmentData(boundary, name: "track", attachmentFilename: "trackfile", theData: AudioCache.trackAudioAsData(track)))
        dataPiecesForBody.appendData("--\(boundary)--\r\n".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!)
        return dataPiecesForBody
    }
    
    private func escapedParameters(parameters: [String : AnyObject]) -> String {
        var urlVars = [String]()
        
        for (key, value) in parameters {
            // make sure that it is a string value
            let stringValue = "\(value)"
            // Escape it
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            // Append it
            if let unwrappedEscapedValue = escapedValue {
                urlVars += [key + "=" + "\(unwrappedEscapedValue)"]
            } else {
                print("Warning: trouble excaping string \"\(stringValue)\"")
            }
        }
        return (!urlVars.isEmpty ? "?" : "") + urlVars.joinWithSeparator("&")
    }

}