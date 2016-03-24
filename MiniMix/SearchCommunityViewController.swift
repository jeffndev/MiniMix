//
//  SearchCommunityViewController.swift
//  MiniMix
//
//  Created by Jeff Newell on 3/21/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import UIKit
import AVFoundation
import CoreData

protocol SongSearchPlaybackDelegate {
    func playSong(cell: SearchSongsCell, song: SongMixLite)
    func stopSong(cell: SearchSongsCell, song: SongMixLite)
    func downloadSong(cell: SearchSongsCell, song: SongMixLite)
}
//NOTE: this searches for the non-private uploaded mixes, but from OTHER users, not yourself.
//  If you want to re-synchronize your own mixes, that will be a sync button included somewhere on the SongListViewController
class SearchCommunityViewController: UIViewController {
    let CELL_ID = "SearchCell"
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    
    var currentUser: User!
    var currentResults = [SongMixLite]()
    var player: AVAudioPlayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        searchBar.delegate = self
        
        //USER
        do {
            try fetchUserResultsController.performFetch()
        } catch {}
        
        guard let fetchedUsers = fetchUserResultsController.fetchedObjects as? [User] else {
            abort()
        }
        if !fetchedUsers.isEmpty {
            currentUser = fetchedUsers.first!
        } else {
            abort()
        }
    }

    @IBAction func cancelSearching() {
        if let player = player {
            player.stop()
        }
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    //MARK: Core Data helper objects..
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance.managedObjectContext
    }
    lazy var fetchUserResultsController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "User")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "socialName", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "isMe == %@", true)
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
    }()
    
    func showAlertMsg(title: String?, msg: String) {
        if #available(iOS 8.0, *) {
            let vc = UIAlertController(title: title, message: msg, preferredStyle: .Alert)
            let okAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
            vc.addAction(okAction)
            presentViewController(vc, animated: true, completion: nil)
        } else {
            // Fallback on earlier versions
        }
    }

}


//MARK: UITableView Delegate/DataSource protocols
extension SearchCommunityViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentResults.count
    }
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(CELL_ID) as! SearchSongsCell
        let song = currentResults[indexPath.row]
        cell.delegate = self
        cell.songInfo = song
        cell.displayLabel.text = "\(song.name) by \(song.userDisplayName)"
        return cell
    }
}

extension SearchCommunityViewController: UISearchBarDelegate {
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText == "" {
            currentResults = [SongMixLite]()
            tableView.reloadData()
            return
        }
        let api = MiniMixCommunityAPI()
        api.searchSongs(searchText) { success, json, message, error in
            //search is a non-critical feature, no error display unless specific message received from server API
            guard error == nil else {
                print("search error: \(error!.localizedDescription)")
                return
            }
            guard success else {
                if let msg = message {
                    print(msg)
                    dispatch_async(dispatch_get_main_queue()) {
                        self.showAlertMsg("Search Failure", msg: msg)
                    }
                }
                return
            }
            guard let jsonResponse = json else {
                print("json response from search not valid")
                return
            }
            print(jsonResponse)
            
            self.currentResults = jsonResponse.map() {
                SongMixLite(jsonDictionary: $0)
            }
            print(self.currentResults.count)
            dispatch_async(dispatch_get_main_queue()) {
                self.tableView.reloadData()
            }
        }
    }
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
extension SearchCommunityViewController: SongSearchPlaybackDelegate {
    func playSong(cell: SearchSongsCell, song: SongMixLite) {
        if let songUrl = song.mixFileUrl {
            do {
                let songData = NSData(contentsOfURL: NSURL(string: songUrl)!)
                try player = AVAudioPlayer(data: songData!)
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(AVAudioSessionCategoryPlayback)
                player?.play()
            } catch let playerErr as NSError {
                print("couldn't create player to play the mix: \(playerErr)")
            }
        }
    }
    func stopSong(cell: SearchSongsCell, song: SongMixLite) {
        if let player = player {
            player.stop()
        }
    }
    func downloadSong(cell: SearchSongsCell, song: SongMixLite) {
        //GET USER for Song (maybe you already have it, maybe not. If not create it here and save it
        let fetchRequest = NSFetchRequest(entityName: "User")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "socialName", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "socialName == %@", song.userDisplayName)
        let sharedContext = CoreDataStackManager.sharedInstance.managedObjectContext
        var remoteUser: User?
        do {
            if let usersFetched = try sharedContext.executeFetchRequest(fetchRequest) as? [User] {
                assert(usersFetched.count < 2)
                if !usersFetched.isEmpty {
                    remoteUser = usersFetched.first!
                    if remoteUser!.isMe {
                        return
                    }
                }
            }
        } catch let userFetchError as NSError {
            print("\(userFetchError)")
            return
        }
        dispatch_async(dispatch_get_main_queue()) {
            if remoteUser === nil {
                remoteUser = User(thisIsMe: false, userEmail: "", userPwd: "", displayName: song.userDisplayName, context: sharedContext)
            }
            let song = SongMix(songInfo: song, context: sharedContext)
            song.artist = remoteUser
            CoreDataStackManager.sharedInstance.saveContext()
        }
    }
}