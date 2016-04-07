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
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
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
        activityIndicator.hidden = true
        activityIndicator.stopAnimating()
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
            doSignUp(nil)
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
        //main purpose is to pull down existing mixes for this user after re-registering
        //step 1.  for each song in the viewed songs, update any versions (UPSYNC)
        dispatch_async(dispatch_get_main_queue()) {
            self.activityIndicator.hidden = false
            self.activityIndicator.startAnimating()
        }
        let songs = songsFetchedResultsControllerForUser.fetchedObjects as! [SongMix]
        var mySongIdSet = Set<String>()
        dispatch_sync(dispatch_get_main_queue()) {
            for song in songs {
                mySongIdSet.insert(song.id)
            }
        }
        for song in songs {
            cloudUploadTasks(song) //server handles version and only updates what's necessary..
        }
        //step 2. get list of songs from cloud (along with versions), if not found on device (or version is less..refresh as needed (DOWNSYNC)
        let api = MiniMixCommunityAPI()
        api.getMyUploadedSongs() { success, jsonResponseArr, message, error in
            guard error == nil else {
                print("search error: \(error!.localizedDescription)")
                dispatch_async(dispatch_get_main_queue()) {
                    self.activityIndicator.hidden = true
                    self.activityIndicator.stopAnimating()
                }
                return
            }
            guard success else {
                if let msg = message {
                    dispatch_async(dispatch_get_main_queue()) {
                        self.activityIndicator.hidden = true
                        self.activityIndicator.stopAnimating()
                        self.showAlertMsg("Sync Songs Failure", msg: msg, posthandler: nil)
                    }
                }
                return
            }
            guard let songArray = jsonResponseArr else {
                dispatch_async(dispatch_get_main_queue()) {
                    self.activityIndicator.hidden = true
                    self.activityIndicator.stopAnimating()
                    self.showAlertMsg("Sync Songs Failure", msg: "Server error", posthandler: nil)
                }
                return
            }
            dispatch_async(dispatch_get_main_queue()) {
                let backgroundQueue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
                let sharedContext = CoreDataStackManager.sharedInstance.managedObjectContext
                let _ = songArray.map() {
                    if !mySongIdSet.contains($0[SongMix.Keys.ID] as! String) {
                        let song = SongMix(jsonDictionary: $0, context: sharedContext)
                        let songId = song.id
                        let songName = song.name
                        let mixUrl = song.mixFileUrl
                        dispatch_async(backgroundQueue) {
                            AudioCache.downSyncUserSongFile(songId, songName: songName, songFileRemoteUrl: mixUrl)
                        }
                        song.artist = self.currentUser
                        if let tracks = $0["audio_tracks"] as? [[String: AnyObject]] {
                            let _ = tracks.map() {
                                let track = AudioTrack(dictionary: $0, context: sharedContext)
                                track.song = song
                                let trackId = track.id
                                let trackUrl = track.trackFileUrl
                                dispatch_async(backgroundQueue) {
                                    AudioCache.downSyncUserTrackFile(trackId, parentSongId: songId, trackRemoteUrl: trackUrl)
                                }
                            }
                        }
                    }
                }
                CoreDataStackManager.sharedInstance.saveContext()
                self.activityIndicator.hidden = true //NOTE: some files may be still uploading, but they are meant to be background...
                self.activityIndicator.stopAnimating()
            }
        }
    }

    @IBAction func shareAction() {
        if let indexPath = tableView.indexPathForSelectedRow {
            let song = songsFetchedResultsControllerForUser.objectAtIndexPath(indexPath) as! SongMix
            let songId = song.id
            let songName = song.name
            var nonEmptyTrackIds = [String]()
            for t in song.tracks {
                if t.hasRecordedFile { nonEmptyTrackIds.append(t.id) }
            }
            if !NSFileManager.defaultManager().fileExistsAtPath(AudioCache.mixedSongPath(songId, songName: songName).path!) {
                AudioHelpers.createSongMixFile(songId, songName: songName, trackIds: nonEmptyTrackIds) { success in
                    if success {
                        self.shareMixFile(songId, songName: songName)
                    } //note: fail silently..
                }
            } else {
                shareMixFile(songId, songName: songName)
            }
        }
    }
    func shareMixFile(songId: String, songName: String) {
        let mixUrl = AudioCache.mixedSongPath(songId, songName: songName)
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
            shareViewController.popoverPresentationController?.sourceView = self.view
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
        let targetSection = songsFetchedResultsControllerForUser.sections![section]
        return targetSection.name

    }
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
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
        //four: Delete, ReMix, Edit, Share
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
    
    func doSignUp(postHandler: (() -> Void)?) {
        let signInViewController = storyboard?.instantiateViewControllerWithIdentifier("CommunitySignInViewController") as! CommunityShareSignInViewController
        signInViewController.postSigninCompletion = postHandler
        presentViewController(signInViewController, animated: true, completion: nil)
    }
    
    
    func toCloudAction(indexPath: NSIndexPath) {
        let song = songsFetchedResultsControllerForUser.objectAtIndexPath(indexPath) as! SongMix
        if !currentUser.isRegistered || currentUser.email.isEmpty || currentUser.servicePassword.isEmpty {
            doSignUp() {
                self.toCloudHandler(song)
            }
        } else {
            toCloudHandler(song)
        }
    }
    
    func toCloudHandler(song: SongMix) {
        let api = MiniMixCommunityAPI()
        api.verifyAuthTokenOrSignin(currentUser.email, password: currentUser.servicePassword) { success, message, error in
            guard success else {
                let msg = message ?? "Could not authenticate with the server"
                self.showAlertMsg("Upload Failure", msg: msg, posthandler: nil)
                return
            }
            if #available(iOS 8.0, *) {
                let alert = UIAlertController(title: "Share to Cloud", message: nil, preferredStyle: .Alert) //maybe .Alert style better??
                let shareWithCommunity = UIAlertAction(title: "Share with Community", style: .Default) { action in
                    dispatch_sync(dispatch_get_main_queue()) {
                        song.keepPrivate = false
                    }
                    self.cloudUploadTasks(song)
                }
                alert.addAction(shareWithCommunity)
                let savePrivate = UIAlertAction(title: "Save as Private", style: .Default) { action in
                    dispatch_sync(dispatch_get_main_queue()) {
                        song.keepPrivate = true
                    }
                    self.cloudUploadTasks(song)
                }
                alert.addAction(savePrivate)
                dispatch_async(dispatch_get_main_queue()) {
                    alert.popoverPresentationController?.sourceView = self.view
                    alert.popoverPresentationController?.sourceRect = CGRectMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0, 1.0, 1.0)
                    self.presentViewController(alert, animated: true, completion: nil)
                    alert.view.layoutIfNeeded()
                    
                }
            } else {
                //TODO: Fallback on earlier versions
            }
        }
    }
    
    func cloudUploadTasks(song: SongMix) {
        var coreRecordedTracksTry: [AudioTrack]?
        var songDtoTry: SongMixDTO?
        dispatch_sync(dispatch_get_main_queue()) {
            coreRecordedTracksTry = song.tracks.filter { $0.hasRecordedFile }
            songDtoTry = SongMixDTO(songObject: song, includeTrackInfo: true)
        }
        guard let songDto = songDtoTry, coreRecordedTracks = coreRecordedTracksTry else {
            return
        }
        
        let parentSongId = songDto.id
        let api = MiniMixCommunityAPI()
        api.uploadSong(songDto) { success, jsonData, message, error in
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
                song.s3RandomId = s3Id
                song.mixFileUrl = remoteUrl
                CoreDataStackManager.sharedInstance.saveContext()
            }
            for track in coreRecordedTracks {
                var trackId = ""
                dispatch_sync(dispatch_get_main_queue()) {
                    trackId = track.id
                }
                api.uploadTrackFile(trackId, parentSongId: parentSongId) { success, jsonData, message, error in
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

    func showAlertMsg(title: String?, msg: String, posthandler: (() -> Void)?) {
        if #available(iOS 8.0, *) {
            dispatch_async(dispatch_get_main_queue()){
                let vc = UIAlertController(title: title, message: msg, preferredStyle: .Alert)
                let okAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
                vc.addAction(okAction)
                vc.popoverPresentationController?.sourceView = self.view
                self.presentViewController(vc, animated: true, completion: posthandler)
            }
        } else {
            //TODO: Fallback on earlier versions, possible version 2.0 item, support for ios 7
        }
    }
    
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
                path = AudioCache.trackPath(track.id, parentSongId: song.id)
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
            doSignUp(nil)
            return
        }
        let api = MiniMixCommunityAPI()
        api.verifyAuthTokenOrSignin(currentUser.email, password: currentUser.servicePassword) { success, message, error in
            guard success else {
                let msg = message ?? "Could not authenticate with the server"
                self.showAlertMsg("Sync Upload Failure", msg: msg, posthandler: nil)
                return
            }
            self.cloudUploadTasks(song)
        }
    }
}
//MARK: AVAudioPlayerDelegate
extension SongListViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
        for player in players {
            //only after the last player is done, since this is playing multiple tracks, which could be different durations..
            if player.playing { return }
        }
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
        //print(song.name)
        //print(song.version)
        cell.songCommentLabel.text = song.songDescription ?? ""
        cell.songStarsRankLable.text = song.rating == nil ? "" : String(Int(song.rating!))
        cell.song = song
        cell.delegate = self
        cell.setUploadedState(song.wasUploaded)
        cell.setBusyState(false)
        let currentUserEmail = currentUser.email
        let currentUserPwd = currentUser.servicePassword
        let songId = song.id
        let songVersion = Int(song.version)
        
        if let artist = song.artist where artist.isMe && song.wasUploaded {
            //Check if YOUR song has changed (higher version), should Sync to Cloud...but only for YOUR songs
            let api = MiniMixCommunityAPI()
            api.verifyAuthTokenOrSignin(currentUserEmail, password: currentUserPwd) { success, message, error in
                guard success else {
                    //Quiet failure, non-critical feature
                    return
                }
                api.songCloudVersionOutOfDateCheck(songId, localSongVersion: songVersion) { success, istrue, message, error in
                    guard success, let isOutOfDate = istrue else {
                        return
                    }
                    cell.setSyncWarningState(isOutOfDate)
                }
            }
        }
    }
}