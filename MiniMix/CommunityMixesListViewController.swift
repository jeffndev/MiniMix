//
//  CommunityMixesListViewController.swift
//  MiniMix
//
//  Created by Jeff Newell on 3/21/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import UIKit
import AVFoundation
import CoreData


class CommunityMixesListViewController: SongListViewController {
    
   
    @IBOutlet weak var searchButton: UIBarButtonItem!
    
    //MARK: Lifecycle overrides...
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        searchButton.enabled = true
    }
    
    //MARK: Fetched Results Controllers And Core Data helper objects
    override func initializeSongFetchResultsController() {
        let fetchRequest = NSFetchRequest(entityName: "SongMix")
        fetchRequest.sortDescriptors = [ NSSortDescriptor(key: "genre", ascending: true), NSSortDescriptor(key: "name", ascending: true) ]
        fetchRequest.predicate = NSPredicate(format: "artist != %@", self.currentUser)
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: "genre",
            cacheName: nil)
        
        songsFetchedResultsControllerForUser = fetchedResultsController
    }

    //MARK: Actions..
    @IBAction func doSongSearch() {
        guard currentUser.isRegistered && !currentUser.email.isEmpty && !currentUser.servicePassword.isEmpty else {
            doSignUp()
            return
        }
        let searchViewController = storyboard?.instantiateViewControllerWithIdentifier("SearchCommunityViewController") as! SearchCommunityViewController
        presentViewController(searchViewController, animated: true, completion: nil)
    }
    //MARK: Table View Delegate overrides
    @available(iOS 8.0, *)
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        //three: Delete, ReMix, Edit, Share
        let delete = UITableViewRowAction(style: .Destructive, title: "Delete") { action, idxPath in
            self.deleteAction(idxPath)
        }
        return [delete]
    }
    override func configureCell(cell: SongListingTableViewCell, withSongMix song: SongMix) {
        super.configureCell(cell, withSongMix: song)
        if let artistNameLbl =  cell.artistName, let artist = song.artist {
            //TODO: gotta figure out, in storyboard where this is going to fit in that cell..its already pretty tight
            artistNameLbl.text = artist.socialName
        }
        cell.contentView.alpha = song.keepPrivate ? 0.3 : 1.0
    }
}

//MARK: SongPlayback Delegate Protocols...
extension CommunityMixesListViewController {
    override func playSong(cell: SongListingTableViewCell, song: SongMix) {
        //check if private, don't play if so...and possibly..erase from the db?
        guard currentPlayingCellRef == nil else {
            print("another mix is playing..have to wait")
            //someone else is playing..wait until they're done..
            cell.setReadyToPlayUIState(true)
            return
        }
        currentPlayingCellRef = cell
        //cell.setReadyToPlayUIState(true) //
        let api = MiniMixCommunityAPI()
        api.verifyAuthTokenOrSignin(currentUser.email, password: currentUser.servicePassword) { success, message, error in
            guard success else {
                self.currentPlayingCellRef = nil
                cell.setReadyToPlayUIState(true)
                let msg = message ?? "Could not authenticate with the server"
                self.showAlertMsg("Player Failure", msg: msg, posthandler: nil)
                return
            }
            api.checkIfSongIsPrivate(song) { success, istrue, message, error in
                guard success, let isprivate = istrue else {
                    self.currentPlayingCellRef = nil
                    cell.setReadyToPlayUIState(true)
                    return
                }
                dispatch_async(dispatch_get_main_queue()){
                    song.keepPrivate = isprivate
                    CoreDataStackManager.sharedInstance.saveContext()
                }
                if !isprivate {
                    cell.setReadyToPlayUIState(!self.playMixImplementation(song))
                } else {
                    self.currentPlayingCellRef = nil
                    cell.setReadyToPlayUIState(true)
                    dispatch_async(dispatch_get_main_queue()){
                        self.showAlertMsg("Private Song", msg: "This song has been made private to the community by the artist.", posthandler: nil)
                    }
                }
            }
        }
    }
    
    override func playMixImplementation(song: SongMix) -> Bool{
        players.removeAll()
        if let songUrl = song.mixFileUrl {
            do {
                let songDataTry = NSData(contentsOfURL: NSURL(string: songUrl)!)
                guard let songData = songDataTry else {
                    dispatch_async(dispatch_get_main_queue()) {
                        self.showAlertMsg("Song Play", msg: "Could not load song data from the network", posthandler: nil)
                    }
                    return false
                }
                let player = try AVAudioPlayer(data: songData)
                player.delegate = self
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(AVAudioSessionCategoryPlayback)
                players.append(player)
                for player in players {
                    player.prepareToPlay()
                }
                for player in players {
                    player.play()
                }
                return true
            } catch let playerErr as NSError {
                print("couldn't create player to play the mix: \(playerErr)")
                return false
            }
        } else {
            return false
        }
    }
}
