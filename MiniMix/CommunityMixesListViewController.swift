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
        
        //TODO: if user is not registered, force them to do so at this juncture..
        if !currentUser.isRegistered || currentUser.servicePassword.isEmpty || currentUser.email.isEmpty {
            
        }
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
    }
}

//MARK: SongPlayback Delegate Protocols...
extension CommunityMixesListViewController {
    override func playMixNaiveImplementation(song: SongMix) -> Bool{
        players.removeAll()
        if let songUrl = song.mixFileUrl {
            do {
                let songDataTry = NSData(contentsOfURL: NSURL(string: songUrl)!)
                guard let songData = songDataTry else {
                    dispatch_async(dispatch_get_main_queue()) {
                        self.showAlertMsg("Song Play", msg: "Could not load song data from the network")
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
