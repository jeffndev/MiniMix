//
//  SongListViewController.swift
//  MiniMix
//
//  Created by Jeff Newell on 2/9/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import UIKit
import AVFoundation
import CoreData

protocol SongPlaybackDelegate {
    func playSong(cell: SongListingTableViewCell, song: SongMix)
    func stopSong(cell: SongListingTableViewCell, song: SongMix)
    func syncSongWithCloud(cell: SongListingTableViewCell, song: SongMix)
}

class SongListViewController: UIViewController {

    let CELL_ID = "SongCell"
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var shareButton: UIBarButtonItem!
    @IBOutlet weak var cloudSyncButton: UIBarButtonItem!
    
    var currentUser: User!
    var players = [AVAudioPlayer]()
    var currentPlayingCellRef: SongListingTableViewCell!
    
    //MARK: Lifecycle overrides...
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
       
        //USER
        do {
            try userFetchedResultsController.performFetch()
        } catch {}
        
        guard let fetchedUsers = userFetchedResultsController.fetchedObjects as? [User] else {
            abort()
        }
        if !fetchedUsers.isEmpty {
            currentUser = fetchedUsers.first!
            assert(currentUser.isMe)
        } else {
            //initiate the user...
            currentUser = User(thisIsMe: true, context: sharedContext)
            CoreDataStackManager.sharedInstance.saveContext()
        }
        print("user name: \(currentUser.socialName)")
        //if !currentUser.socialName.isEmpty { self.title = "Mini Mix for \(currentUser.socialName)" }
        //SONGS for User
        if songsFetchedResultsControllerForUser == nil {
            initializeSongFetchResultsController()
        }
        do {
            try songsFetchedResultsControllerForUser.performFetch()
        } catch {}
        songsFetchedResultsControllerForUser.delegate = self
        print("song count: \(songsFetchedResultsControllerForUser.fetchedObjects!.count)")
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        tableView.reloadData()
        if let shareButton = shareButton {
            shareButton.enabled = false
        }
    }
    
    //MARK: Fetched Results Controllers And Core Data helper objects
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance.managedObjectContext
    }
    lazy var userFetchedResultsController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "User")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "socialName", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "isMe == %@", true)
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
    }()
    
    var songsFetchedResultsControllerForUser: NSFetchedResultsController!
    
    func initializeSongFetchResultsController() {
        let fetchRequest = NSFetchRequest(entityName: "SongMix")
        fetchRequest.sortDescriptors = [ NSSortDescriptor(key: "genre", ascending: true), NSSortDescriptor(key: "name", ascending: true) ]
        fetchRequest.predicate = NSPredicate(format: "artist == %@", self.currentUser)
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: "genre",
            cacheName: nil)
        
        songsFetchedResultsControllerForUser = fetchedResultsController
    }

    //MARK: Actions.....
    @IBAction func addNewSong() {
        let recordViewController = storyboard!.instantiateViewControllerWithIdentifier("SongMixerViewController") as! SongMixerViewController
        let newSong = SongMix(songName: "New Song", insertIntoManagedObjectContext: sharedContext)
        newSong.artist = currentUser
        CoreDataStackManager.sharedInstance.saveContext()
        print("song count: \(songsFetchedResultsControllerForUser.fetchedObjects!.count)")
        recordViewController.song = newSong
        navigationController!.pushViewController(recordViewController, animated: true)
    }
    @IBAction func cloudReSyncAction() {
        guard currentUser.isRegistered && !currentUser.email.isEmpty && !currentUser.servicePassword.isEmpty else {
            doSignUp()
            return
        }
        let api = MiniMixCommunityAPI()
        api.verifyAuthTokenOrSignin(currentUser.email, password: currentUser.servicePassword) { success, message, error in
            guard success else {
                let msg = message ?? "Could not authenticate with the server"
                self.showAlertMsg("Cloud Sync Failure", msg: msg, posthandler: nil)
                return
            }
            self.cloudSyncTask()
        }
    }
    func cloudSyncTask() {
        //TODO: PROGRESS or ACTIVITY INDICATOR??
        //main purpose is to pull down existing mixes for this user after re-registering
        //step 1.  for each song in the viewed songs, update any versions (UPSYNC)
        let songs = songsFetchedResultsControllerForUser.fetchedObjects as! [SongMix]
        var songIdSet = Set<String>()
        for song in songs {
            songIdSet.insert(song.id)
            cloudUploadTasks(song, keepPrivate: song.keepPrivate) //server handles version and only updates what's necessary..
        }
        //step 2. get list of songs from cloud (along with versions), if not found on device (or version is less..refresh as needed (DOWNSYNC)
        let api = MiniMixCommunityAPI()
        api.getMyUploadedSongs() { success, jsonResponseArr, message, error in
            guard error == nil else {
                print("search error: \(error!.localizedDescription)")
                return
            }
            guard success else {
                if let msg = message {
                    dispatch_async(dispatch_get_main_queue()) {
                        self.showAlertMsg("Sync Songs Failure", msg: msg, posthandler: nil)
                    }
                }
                return
            }
            guard let songArray = jsonResponseArr else {
                dispatch_async(dispatch_get_main_queue()) {
                    self.showAlertMsg("Sync Songs Failure", msg: "Server error", posthandler: nil)
                }
                return
            }
            dispatch_async(dispatch_get_main_queue()) {
                let backgroundQueue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
                let sharedContext = CoreDataStackManager.sharedInstance.managedObjectContext
                let _ = songArray.map() {
                    if !songIdSet.contains($0[SongMix.Keys.ID] as! String) {
                        let song = SongMix(jsonDictionary: $0, context: sharedContext)
                        dispatch_async(backgroundQueue) {
                            self.downSyncUserSongFile(song)
                        }
                        song.artist = self.currentUser
                        if let tracks = $0["audio_tracks"] as? [[String: AnyObject]] {
                            let _ = tracks.map() {
                                let track = AudioTrack(dictionary: $0, context: sharedContext)
                                track.song = song
                                dispatch_async(backgroundQueue) {
                                    self.downSyncUserTrackFile(track)                                }
                            }
                        }
                    }
                }
                CoreDataStackManager.sharedInstance.saveContext()
            }
        }
    }
    
    func downSyncUserSongFile(song: SongMix) {
        //create subdirectory in Documents for the SONG, the tracks and mix go in there...
        if !NSFileManager.defaultManager().fileExistsAtPath(AudioCache.songDirectory(song)) {
            do {
                try NSFileManager.defaultManager().createDirectoryAtPath(AudioCache.songDirectory(song), withIntermediateDirectories: true, attributes: nil)
            } catch let error as NSError {
                print("could not create song directory, not able to prepare for recording: \(error.localizedDescription)")
                return
            }
        }
        guard !NSFileManager.defaultManager().fileExistsAtPath(AudioCache.mixedSongPath(song).path!) else {
            print("mix file already exists locally, not downloading")
            return
        }
        guard let songUrl = song.mixFileUrl else {
            return
        }
        guard let songData = NSData(contentsOfURL: NSURL(string: songUrl)!) else {
            return
        }
        songData.writeToURL(AudioCache.mixedSongPath(song), atomically: true)
        print("mix file for song: \(song.name) downloaded locally with Sync")
    }
            
    func downSyncUserTrackFile(track: AudioTrack) {
        //create subdirectory in Documents for the SONG, the tracks and mix go in there...
        if !NSFileManager.defaultManager().fileExistsAtPath(AudioCache.songDirectory(track.song!)) {
            do {
                try NSFileManager.defaultManager().createDirectoryAtPath(AudioCache.songDirectory(track.song!), withIntermediateDirectories: true, attributes: nil)
            } catch let error as NSError {
                print("could not create song directory, not able to prepare for recording: \(error.localizedDescription)")
                return
            }
        }
        guard !NSFileManager.defaultManager().fileExistsAtPath(AudioCache.trackPath(track, parentSong: track.song!).path!) else {
            print("track file already exists locally, not downloading")
            return
        }
        guard let trackUrl = track.trackFileUrl else {
            return
        }
        guard let trackData = NSData(contentsOfURL: NSURL(string: trackUrl)!) else {
            return
        }
        trackData.writeToURL(AudioCache.trackPath(track, parentSong: track.song!), atomically: true)
        print("track file \(track.name) for song: \(track.song!.name) downloaded locally with Sync")
    }
    
    @IBAction func shareAction() {
        if let indexPath = tableView.indexPathForSelectedRow {
            let song = songsFetchedResultsControllerForUser.objectAtIndexPath(indexPath) as! SongMix
            if !NSFileManager.defaultManager().fileExistsAtPath(AudioCache.mixedSongPath(song).path!) {
                AudioHelpers.createSongMixFile(song) { success in
                    if success {
                        self.shareMixFile(song)
                    } //note: fail silently..
                }
            } else {
                shareMixFile(song)
            }
            print("Shareing for song name: \(song.name)")
        }
    }
    func shareMixFile(song: SongMix) {
        let mixUrl = AudioCache.mixedSongPath(song)
        guard NSFileManager.defaultManager().fileExistsAtPath(mixUrl.path!) else {
            print("Could not find mix file")
            return
        }
        dispatch_async(dispatch_get_main_queue()) {
            let shareViewController = UIActivityViewController(activityItems: [mixUrl], applicationActivities: nil)
            if #available(iOS 8.0, *) {
                shareViewController.completionWithItemsHandler = {
                    (activity, success, items, error) in
                    self.dismissViewControllerAnimated(true, completion: nil)
                }
            } else {
                // Fallback on earlier versions
            }
            self.presentViewController(shareViewController, animated: true, completion: nil)
        }
    }
    
}
//MARK: table view data soure and delegate protocols
extension SongListViewController: UITableViewDataSource, UITableViewDelegate {
    //MARK: Data Source protocols
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let targetSection = songsFetchedResultsControllerForUser.sections![section]
        return targetSection.numberOfObjects
    }
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(CELL_ID) as! SongListingTableViewCell
        let song = songsFetchedResultsControllerForUser.objectAtIndexPath(indexPath) as! SongMix
        configureCell(cell, withSongMix: song)
        return cell
    }
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        //THE NAME OF THE GENRE
        //return SongMix.genres[section]
        let targetSection = songsFetchedResultsControllerForUser.sections![section]
        return targetSection.name

    }
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        //return SongMix.genres.count
        return songsFetchedResultsControllerForUser.sections!.count
    }
    //MARK: Delegate protocols
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if let shareButton = shareButton {
            shareButton.enabled = true
        }
    }
    func tableView(tableView: UITableView, didDeselectRowAtIndexPath indexPath: NSIndexPath) {
        if let shareButton = shareButton {
            shareButton.enabled = false
        }
    }
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        //EMPTY...handled by the actions below
    }
    
    @available(iOS 8.0, *)
    func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        //three: Delete, ReMix, Edit, Share
        let delete = UITableViewRowAction(style: .Destructive, title: "Delete") { action, idxPath in
            self.deleteAction(idxPath)
        }
        let share = UITableViewRowAction(style: .Normal, title: "Cloud") { action, idxPath in
            self.toCloudAction(idxPath)
        }
        share.backgroundColor = UIColor(red: 34.0/255.0, green: 255.0/255.0, blue: 6.0/255.0, alpha: 1.0)  //UIColor.greenColor()
        let reMix = UITableViewRowAction(style: .Normal, title: "Remix") {
            action, idxPath in
            self.remixAction(idxPath)
        }
        reMix.backgroundColor = UIColor(red: 133.0/255.0, green: 57.0/255.0, blue: 10.0/255.0, alpha: 1.0)  //UIColor.brownColor()
        let editInfo = UITableViewRowAction(style: .Normal, title: "Edit") { action, idxPath in
            self.editinfoAction(idxPath)
        }
        editInfo.backgroundColor = UIColor(red: 17.0/255.0, green: 135.0/255.0, blue: 195.0/255.0, alpha: 1.0) //UIColor.blueColor()
        return [delete, reMix, editInfo, share]
    }
    
    func deleteAction(indexPath: NSIndexPath) {
        let song = songsFetchedResultsControllerForUser.objectAtIndexPath(indexPath) as! SongMix
        sharedContext.deleteObject(song)
        CoreDataStackManager.sharedInstance.saveContext()
    }
    
    func doSignUp() {
        let signInViewController = storyboard?.instantiateViewControllerWithIdentifier("CommunitySignInViewController") as! CommunityShareSignInViewController
        presentViewController(signInViewController, animated: true, completion: nil)
    }
    
    func toCloudAction(indexPath: NSIndexPath) {
        let song = songsFetchedResultsControllerForUser.objectAtIndexPath(indexPath) as! SongMix
        
        guard currentUser.isRegistered && !currentUser.email.isEmpty && !currentUser.servicePassword.isEmpty else {
            doSignUp()
            return
        }
        let api = MiniMixCommunityAPI()
        api.verifyAuthTokenOrSignin(currentUser.email, password: currentUser.servicePassword) { success, message, error in
            guard success else {
                let msg = message ?? "Could not authenticate with the server"
                self.showAlertMsg("Upload Failure", msg: msg, posthandler: nil)
                return
            }
            if #available(iOS 8.0, *) {
                let alert = UIAlertController(title: "Share to Cloud", message: nil, preferredStyle: .ActionSheet) //maybe .Alert style better??
                let shareWithCommunity = UIAlertAction(title: "Share with Community", style: .Default) { action in
                    self.cloudUploadTasks(song, keepPrivate: false)
                }
                alert.addAction(shareWithCommunity)
                let savePrivate = UIAlertAction(title: "Save as Private", style: .Default) { action in
                    self.cloudUploadTasks(song, keepPrivate: true)
                }
                alert.addAction(savePrivate)
                dispatch_async(dispatch_get_main_queue()) {
                    self.presentViewController(alert, animated: true, completion: nil)
                }
            } else {
                //TODO: Fallback on earlier versions
            }
        }
    }
        
    func showAlertMsg(title: String?, msg: String, posthandler: (() -> Void)?) {
        if #available(iOS 8.0, *) {
            let vc = UIAlertController(title: title, message: msg, preferredStyle: .Alert)
            let okAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
            vc.addAction(okAction)
            presentViewController(vc, animated: true, completion: posthandler)
        } else {
            //TODO: Fallback on earlier versions
        }
    }
    
    func cloudUploadTasks(song: SongMix, keepPrivate: Bool) {
        let api = MiniMixCommunityAPI()
        api.uploadSong(keepPrivate, song: song) { success, jsonData, message, error in
            guard success && jsonData != nil else {
                dispatch_async(dispatch_get_main_queue()) {
                    self.showAlertMsg("Cloud Upload", msg: "Song failed to upload, please try again", posthandler: nil)
                }
                return
            }
            //HANDLE SONG UPLOAD JSON RESPONSE.........
            dispatch_async(dispatch_get_main_queue()) {
                guard let remoteUrl = jsonData![SongMix.Keys.MixFileRemoteUrl] as? String, let s3Id = jsonData![SongMix.Keys.S3RandomId] as? String else {
                    self.showAlertMsg("Cloud Upload", msg: "Song failed to upload properly, no links returned, please try again", posthandler: nil)
                    return
                }
                song.keepPrivate = keepPrivate
                song.s3RandomId = s3Id
                song.mixFileUrl = remoteUrl
                CoreDataStackManager.sharedInstance.saveContext()
            }
            for track in song.tracks where track.hasRecordedFile {
                api.uploadTrackFile(track) { success, jsonData, message, error in
                    if success && jsonData != nil{
                        dispatch_async(dispatch_get_main_queue()) {
                            if let remoteTrackUrl = jsonData![AudioTrack.Keys.TrackFileRemoteUrl] as? String, let s3Id = jsonData![AudioTrack.Keys.S3RandomId] as? String {
                                track.trackFileUrl = remoteTrackUrl
                                track.s3RandomId = s3Id
                                CoreDataStackManager.sharedInstance.saveContext()
                            }
                        }
                    }
                }
            }
            //END HANDLE SONG UPLOAD JSON RESPONSE.......
        }
    }
    
//    func cloudUploadActivity(song: SongMix, keepPrivate: Bool) {
//        //TODO: this function is a bear...need to clean it up...
//        guard let currentUser = currentUser else {
//            print("nil current user...")
//            return
//        }
//        let userEmail = currentUser.email
//        let userPwd = currentUser.servicePassword
//        let userMoniker = currentUser.socialName
//        
//        if !currentUser.isRegistered || currentUser.servicePassword.isEmpty || currentUser.email.isEmpty {
//            let signInViewController = storyboard?.instantiateViewControllerWithIdentifier("CommunitySignInViewController") as! CommunityShareSignInViewController
//            presentViewController(signInViewController, animated: true) {
//                if self.currentUser.isRegistered {
//                    let api = MiniMixCommunityAPI()
//                    api.uploadSong(userEmail, password: userPwd, keepPrivate: keepPrivate, song: song) { success, jsonData, message, error in
//                        //TODO: probably want to indicate the "uploaded_to_cloud", the song and tracks s3 urls and id's and save locally..
//                        if !success || jsonData == nil {
//                            dispatch_async(dispatch_get_main_queue()) {
//                                self.showAlertMsg("Cloud Upload", msg: "Song failed to upload, please try again")
//                            }
//                            return
//                        }
//                        dispatch_async(dispatch_get_main_queue()) {
//                            if let remoteUrl = jsonData![SongMix.Keys.MixFileRemoteUrl] as? String {
//                                song.mixFileUrl = remoteUrl
//                            }
//                            if let s3Id = jsonData![SongMix.Keys.S3RandomId] as? String {
//                                song.s3RandomId = s3Id
//                            }
//                            CoreDataStackManager.sharedInstance.saveContext()
//                        }
//                        for track in song.tracks {
//                            if !track.hasRecordedFile { continue }//WARNING: repeated code...see below
//                            api.uploadTrackFile(userEmail, password: userPwd, track: track) { success, jsonData, message, error in
//                                if success && jsonData != nil{
//                                    //TODO: save the track url and s3 id to the db..
//                                    dispatch_async(dispatch_get_main_queue()) {
//                                        if let remoteTrackUrl = jsonData![AudioTrack.Keys.TrackFileRemoteUrl] as? String {
//                                            track.trackFileUrl = remoteTrackUrl
//                                        }
//                                        if let s3Id = jsonData![AudioTrack.Keys.S3RandomId] as? String {
//                                            track.s3RandomId = s3Id
//                                        }
//                                        CoreDataStackManager.sharedInstance.saveContext()
//                                    }
//                                }
//
//                            }
//                        }
//                    }
//                } else {
//                    //TODO: fail somehow..gotta let user know
//                }
//            }
//        } else {
//            let api = MiniMixCommunityAPI()
//            api.signin(userEmail, password: userPwd, publicName: userMoniker) { success, message, error in
//                if(success) {
//                    //let inner_api = MiniMixCommunityAPI()
//                    api.uploadSong(userEmail, password: userPwd, keepPrivate: keepPrivate, song: song) { success, jsonData, message, error in
//                         //WARNING: repeated code...see above
//                        if !success || jsonData == nil {
//                            dispatch_async(dispatch_get_main_queue()) {
//                                self.showAlertMsg("Cloud Upload", msg: "Song failed to upload, please try again")
//                            }
//                            return
//                        }
//                        dispatch_async(dispatch_get_main_queue()) {
//                            if let remoteUrl = jsonData![SongMix.Keys.MixFileRemoteUrl] as? String {
//                                song.mixFileUrl = remoteUrl
//                            }
//                            if let s3Id = jsonData![SongMix.Keys.S3RandomId] as? String {
//                                song.s3RandomId = s3Id
//                            }
//                            CoreDataStackManager.sharedInstance.saveContext()
//                        }
//                        for track in song.tracks {
//                            if !track.hasRecordedFile { continue }
//                            api.uploadTrackFile(userEmail, password: userPwd, track: track) { success, jsonData, message, error in
//                                if success && jsonData != nil{
//                                    //TODO: save the track url and s3 id to the db..
//                                    dispatch_async(dispatch_get_main_queue()) {
//                                        if let remoteTrackUrl = jsonData![AudioTrack.Keys.TrackFileRemoteUrl] as? String {
//                                            track.trackFileUrl = remoteTrackUrl
//                                        }
//                                        if let s3Id = jsonData![AudioTrack.Keys.S3RandomId] as? String {
//                                            track.s3RandomId = s3Id
//                                        }
//                                        CoreDataStackManager.sharedInstance.saveContext()
//                                    }
//                                }
//                            }
//                        }
//                    }
//                } else {
//                    //have to figure out which kinds of errors...if need to signup again or something would need the signin modal, otherwise, just tell user sorry, try again
//                }
//            }
//        }
//    }
    
    func remixAction(indexPath: NSIndexPath) {
        let song = songsFetchedResultsControllerForUser.objectAtIndexPath(indexPath) as! SongMix
        let recordViewController = storyboard!.instantiateViewControllerWithIdentifier("SongMixerViewController") as! SongMixerViewController
        recordViewController.song = song
        navigationController!.pushViewController(recordViewController, animated: true)
    }
    func editinfoAction(indexPath: NSIndexPath) {
        let song = songsFetchedResultsControllerForUser.objectAtIndexPath(indexPath) as! SongMix
        let songInfoViewController = storyboard?.instantiateViewControllerWithIdentifier("SongInfoViewController") as! SongInfoViewController
        songInfoViewController.song = song
        presentViewController(songInfoViewController, animated: true, completion: nil)
    }
}
//MARK: SongPlayback Delegate Protocols...
extension SongListViewController: SongPlaybackDelegate {
    func playSong(cell: SongListingTableViewCell, song: SongMix) {
        if currentPlayingCellRef == nil {
            let playerIsPlaying = playMixImplementation(song)
            if playerIsPlaying { currentPlayingCellRef = cell }
            cell.setReadyToPlayUIState(!playerIsPlaying)
        } else {
            print("someone else is playing..wait until they're done..")
            cell.setReadyToPlayUIState(true)
        }
    }
    func stopSong(cell: SongListingTableViewCell, song: SongMix) {
        currentPlayingCellRef = nil
        let _ = players.map() { $0.stop() }
    }
    
    func playMixImplementation(song: SongMix) -> Bool {
        players.removeAll()
        var path: NSURL
        for track in song.tracks {
            do {
                path = AudioCache.trackPath(track, parentSong: song)
                let player = try AVAudioPlayer(contentsOfURL: path)
                player.volume = track.isMuted ? 0.0 : Float(track.mixVolume)
                player.delegate = self
                players.append(player)
            } catch let error as NSError {
                print("could not create audio player for audio file at \(path.path!)\n  \(error.localizedDescription)")
                return false
            }
        }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(AVAudioSessionCategoryPlayback)
        } catch let sessionErr as NSError {
            print("\(sessionErr)")
            return false
        }
        for player in players {
            player.prepareToPlay()
        }
        for player in players {
            player.play()
        }
        return true
    }
    func syncSongWithCloud(cell: SongListingTableViewCell, song: SongMix) {
        guard currentUser.isRegistered && !currentUser.email.isEmpty && !currentUser.servicePassword.isEmpty else {
            doSignUp()
            return
        }
        let api = MiniMixCommunityAPI()
        api.verifyAuthTokenOrSignin(currentUser.email, password: currentUser.servicePassword) { success, message, error in
            guard success else {
                let msg = message ?? "Could not authenticate with the server"
                self.showAlertMsg("Sync Upload Failure", msg: msg, posthandler: nil)
                return
            }
            self.cloudUploadTasks(song, keepPrivate: song.keepPrivate)
        }
    }
}
//MARK: AVAudioPlayerDelegate
extension SongListViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
        //have to signal to the cell that the
        if let cell = currentPlayingCellRef {
            cell.setReadyToPlayUIState(true)
        }
        currentPlayingCellRef = nil
    }
}
//MARK: FetchedResults Delegate Protocols...
extension SongListViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        tableView.beginUpdates()
    }
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        tableView.endUpdates()
    }
    func controller(controller: NSFetchedResultsController, didChangeSection sectionInfo: NSFetchedResultsSectionInfo, atIndex sectionIndex: Int, forChangeType type: NSFetchedResultsChangeType) {
        
        switch type {
        case .Insert:
            tableView.insertSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Automatic)
        case .Delete:
            tableView.deleteSections(NSIndexSet(index: sectionIndex), withRowAnimation: .Automatic)
        case .Update:
            print("section did change Update: \(sectionInfo.name)")
        case .Move:
            print("section did change Move: \(sectionInfo.name)")
        }
        
    }
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
        switch type {
        case .Insert:
            if let newSong = anObject as? SongMix {
                print("New song genre: \(newSong.genre)")
            }
            print("section of new songs cell: \(newIndexPath!.section)")
            tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Automatic)
        case .Delete:
            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Automatic)
        case .Update:
            guard let cell = tableView.cellForRowAtIndexPath(indexPath!) as? SongListingTableViewCell else {
                print("Could not update cell, was nil")
                return
            }
            if let song = anObject as? SongMix {
                configureCell(cell, withSongMix: song)
            }
        case .Move:
            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
            tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
        }
    }
    //MARK: Configure Cell
    func configureCell( cell: SongListingTableViewCell, withSongMix song: SongMix) {
        cell.songTitleLabel.text = song.name
        print(song.name)
        print(song.version)
        cell.songCommentLabel.text = song.songDescription ?? ""
        cell.songStarsRankLable.text = song.rating == nil ? "" : String(Int(song.rating!))
        cell.song = song
        cell.delegate = self
        
        if let artist = song.artist where artist.isMe {
            //Check if YOUR song has changed (higher version), should Sync to Cloud...but only for YOUR songs
            let api = MiniMixCommunityAPI()
            api.verifyAuthTokenOrSignin(currentUser.email, password: currentUser.servicePassword) { success, message, error in
                guard success else {
                    //Quiet failure, non-critical feature
                    return
                }
                api.songCloudVersionOutOfDateCheck(song) { success, istrue, message, error in
                    guard success, let isOutOfDate = istrue else {
                        return
                    }
                    cell.setSyncWarningState(isOutOfDate)
                }
            }
        }
    }
}