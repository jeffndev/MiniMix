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
    func playSong(song: SongMix)
    func stopSong(song: SongMix)
}

class SongListViewController: UIViewController {

    let CELL_ID = "SongCell"
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var shareButton: UIBarButtonItem!
    
    var initializingUser = true
    var currentUser: User!
    //var songs = [SongMix]()
    var players = [AVAudioPlayer]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
       
        //USER
        initializingUser = true
        do {
            try userFetchedResultsController.performFetch()
        } catch {}
        userFetchedResultsController.delegate = self
        guard let fetchedUsers = userFetchedResultsController.fetchedObjects as? [User] else {
            abort()
        }
        if !fetchedUsers.isEmpty {
            currentUser = fetchedUsers.first!
        } else {
            //initiate the user...
            currentUser = User(context: sharedContext)
            CoreDataStackManager.sharedInstance.saveContext()
        }
        initializingUser = false
        
        //SONGS for User
        do {
            try songsFetchedResultsControllerForUser.performFetch()
        } catch {}
        songsFetchedResultsControllerForUser.delegate = self
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        tableView.reloadData()
        shareButton.enabled = false
    }
    
    //MARK: Fetched Results Controllers And Core Data helper objects
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance.managedObjectContext
    }
    lazy var userFetchedResultsController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "User")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "socialName", ascending: true)]
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
    }()
    
    lazy var songsFetchedResultsControllerForUser: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "SongMix")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "artist == %@", self.currentUser)
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
    }()

    
    @IBAction func addNewSong() {
        let recordViewController = storyboard!.instantiateViewControllerWithIdentifier("SongMixerViewController") as! SongMixerViewController
        let newSong = SongMix(songName: "New Song", insertIntoManagedObjectContext: sharedContext)
        //songs.append(newSong)
        newSong.artist = currentUser
        CoreDataStackManager.sharedInstance.saveContext()
        recordViewController.song = newSong
//        let songsInGenre = songs.filter { $0.genre == newSong.genre }
//        let insertIndexPath = NSIndexPath(forRow: songsInGenre.count - 1, inSection: SongMix.genres.indexOf(newSong.genre)!)
//        tableView.insertRowsAtIndexPaths([insertIndexPath], withRowAnimation: .Automatic)
        navigationController!.pushViewController(recordViewController, animated: true)
    }
    @IBAction func shareAction() {
        if let indexPath = tableView.indexPathForSelectedRow {
            //let song = getSelectedSong(forIndexPath: indexPath)
            let song = songsFetchedResultsControllerForUser.objectAtIndexPath(indexPath) as! SongMix
            if !NSFileManager.defaultManager().fileExistsAtPath(AudioCache.mixedSongPath(song).path!) {
                //TODO: mix it...perhaps dispatch to main queue?
                createSongMixFile(song) { success in
                    if success {
                        self.shareMixFile(song)
                    } else {
                        //TODO: ALERT popup, couldn't create the mix..
                    }
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
    
    func createSongMixFile(song: SongMix, postHandler: (success: Bool) -> Void) {
        let composition = AVMutableComposition()
        var inputMixParms = [AVAudioMixInputParameters]()
        for track in song.tracks {
            let trackUrl = AudioCache.trackPath(track, parentSong: song)
            let audioAsset = AVURLAsset(URL: trackUrl)
            let audioCompositionTrack = composition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: kCMPersistentTrackID_Invalid)
            do {
                try audioCompositionTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, audioAsset.duration), ofTrack: audioAsset.tracksWithMediaType(AVMediaTypeAudio).first!, atTime: kCMTimeZero)
            }catch {
                postHandler(success: false)
                return
            }
            let mixParm = AVMutableAudioMixInputParameters(track: audioCompositionTrack)
            inputMixParms.append(mixParm)
        }
        //EXPORT
        let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A)
        let mixUrl = AudioCache.mixedSongPath(song)
        do {
            try NSFileManager.defaultManager().removeItemAtPath(mixUrl.path!)
        } catch {
            
        }
        if let export = export {
            let mixParms = AVMutableAudioMix()
            mixParms.inputParameters = inputMixParms
            export.audioMix = mixParms
            export.outputFileType = AVFileTypeAppleM4A
            export.outputURL = mixUrl
            export.exportAsynchronouslyWithCompletionHandler {
                postHandler(success: true)
                print("EXPORTED..try to play it now")
            }
        }

    }
}
//MARK: table view data soure and delegate protocols
extension SongListViewController: UITableViewDataSource, UITableViewDelegate {
    //MARK: Data Source protocols
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let songs = songsFetchedResultsControllerForUser.fetchedObjects as! [SongMix]
        let songsInGenre = songs.filter { $0.genre == SongMix.genres[section]}
        return songsInGenre.count
    }
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(CELL_ID) as! SongListingTableViewCell
        //let song = getSelectedSong(forIndexPath: indexPath)
        let song = songsFetchedResultsControllerForUser.objectAtIndexPath(indexPath) as! SongMix
        cell.songTitleLabel.text = song.name
        cell.songCommentLabel.text = song.songDescription ?? ""
        cell.songStarsRankLable.text = song.rating == nil ? "" : String(Int(song.rating!))
        cell.song = song
        cell.delegate = self
        return cell
    }
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        //THE NAME OF THE GENRE
        return SongMix.genres[section]
    }
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return SongMix.genres.count
    }
    //MARK: Delegate protocols
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        shareButton.enabled = true
    }
    func tableView(tableView: UITableView, didDeselectRowAtIndexPath indexPath: NSIndexPath) {
        shareButton.enabled = false
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
        //let song = getSelectedSong(forIndexPath: indexPath)
        let song = songsFetchedResultsControllerForUser.objectAtIndexPath(indexPath) as! SongMix
        sharedContext.deleteObject(song)
        CoreDataStackManager.sharedInstance.saveContext()
        //TODO: this will go away when CoreData is added along with Cascade on the tracks relationship, plus a prepareForDelete on the track objects
//        song.deleteTracks()
//        if let deleteIndex = songs.indexOf(song) {
//            songs.removeAtIndex(deleteIndex)
//        }
//        tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
    }
    func toCloudAction(indexPath: NSIndexPath) {
        //let song = getSelectedSong(forIndexPath: indexPath)
        let song = songsFetchedResultsControllerForUser.objectAtIndexPath(indexPath) as! SongMix
        print("Sharing to cloud: \(song.name)")
    }
    func remixAction(indexPath: NSIndexPath) {
        //let song = getSelectedSong(forIndexPath: indexPath)
        let song = songsFetchedResultsControllerForUser.objectAtIndexPath(indexPath) as! SongMix
        let recordViewController = storyboard!.instantiateViewControllerWithIdentifier("SongMixerViewController") as! SongMixerViewController
        recordViewController.song = song
        navigationController!.pushViewController(recordViewController, animated: true)
    }
    func editinfoAction(indexPath: NSIndexPath) {
        // let song = getSelectedSong(forIndexPath: indexPath)
        let song = songsFetchedResultsControllerForUser.objectAtIndexPath(indexPath) as! SongMix
        let songInfoViewController = storyboard?.instantiateViewControllerWithIdentifier("SongInfoViewController") as! SongInfoViewController
        songInfoViewController.song = song
        presentViewController(songInfoViewController, animated: true, completion: nil)
    }
    
//    func getSelectedSong(forIndexPath indexPath: NSIndexPath) -> SongMix {
//        let songs = songsFetchedResultsControllerForUser.fetchedObjects as! [SongMix]
//        let songsInGenre = songs.filter { $0.genre == SongMix.genres[indexPath.section]}
//        return songsInGenre[indexPath.row]
//    }
}
extension SongListViewController: SongPlaybackDelegate {
    func playSong(song: SongMix) {
        playMixNaiveImplementation(song)
    }
    func stopSong(song: SongMix) {
        let _ = players.map() { $0.stop() }
    }
    
    func playMixNaiveImplementation(song: SongMix) {
        players.removeAll()
        var path: NSURL
        for track in song.tracks {
            do {
                path = AudioCache.trackPath(track, parentSong: song)
                let player = try AVAudioPlayer(contentsOfURL: path)
                player.volume = track.isMuted ? 0.0 : Float(track.mixVolume)
                players.append(player)
            } catch let error as NSError {
                print("could not create audio player for audio file at \(path.path!)\n  \(error.localizedDescription)")
            }
        }
        let session = AVAudioSession.sharedInstance()
        try! session.setCategory(AVAudioSessionCategoryPlayback)
        for player in players {
            player.play()
        }
    }
}

extension SongListViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        if initializingUser {
            return
        }
        tableView.beginUpdates()
    }
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        if initializingUser {
            return
        }
        tableView.endUpdates()
    }
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        if initializingUser {
            return
        }
        switch type {
        case .Insert:
            tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Automatic)
        case .Delete:
            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Automatic)
        case .Update:
            print("update not handled")
        case .Move:
            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
            tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
        }
        
    }
    
}