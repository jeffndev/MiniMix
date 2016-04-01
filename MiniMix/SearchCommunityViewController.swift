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
        cell.songArtistLabel.text = "artist: \(song.userDisplayName)"
        cell.genreLabel.text = song.genre
        cell.songNameLabel.text = song.name
        cell.setReadyToPlayUIState(true)
        cell.setDisabledStateForFailedMixPreviewDownload(false)
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
        api.verifyAuthTokenOrSignin(currentUser.email, password: currentUser.servicePassword) { success, message, error in
            guard success else {
                let msg = message ?? "Could not authenticate with the server"
                self.showAlertMsg("Search Failure", msg: msg)
                return
            }
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
    }
    
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
extension SearchCommunityViewController: SongSearchPlaybackDelegate {
    func playSong(cell: SearchSongsCell, song: SongMixLite) {
        if let songUrl = song.mixFileUrl {
            do {
                //TODO: activity indicator for file download here..
                let songDataTry = NSData(contentsOfURL: NSURL(string: songUrl)!)
                guard let songData = songDataTry else {
                    print("could not download song file to play")
                    cell.setDisabledStateForFailedMixPreviewDownload(true)
                    return
                }
                try player = AVAudioPlayer(data: songData)
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(AVAudioSessionCategoryPlayback)
                if let player = player {
                    if player.playing { player.stop() }
                    player.play()
                }
                cell.setReadyToPlayUIState(false)
            } catch let playerErr as NSError {
                print("couldn't create player to play the mix: \(playerErr)")
                cell.setDisabledStateForFailedMixPreviewDownload(true)
            }
        }
    }
    func stopSong(cell: SearchSongsCell, song: SongMixLite) {
        if let player = player {
            player.stop()
        }
        cell.setReadyToPlayUIState(true)
    }
    
    func checkIfSongExists(songInfo: SongMixLite) -> Bool {
        let fetchRequest = NSFetchRequest(entityName: "SongMix")
        fetchRequest.predicate = NSPredicate(format: "id == %@", songInfo.id)
        let sharedContext = CoreDataStackManager.sharedInstance.managedObjectContext
        var fetchError: NSError? = nil
        let fetchCount  = sharedContext.countForFetchRequest(fetchRequest, error: &fetchError)
        if let fetchError = fetchError{
            print(fetchError)
            return false
        }
        return fetchCount > 0
    }
    func findOrCreateRemoteUserWithName( socialName: String) -> User? {
        //GET USER for Song (maybe you already have it, maybe not. If not create it here and save it
        let fetchRequest = NSFetchRequest(entityName: "User")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "socialName", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "socialName == %@ AND isMe == %@", socialName, false)
        let sharedContext = CoreDataStackManager.sharedInstance.managedObjectContext
        var remoteUser: User?
        do {
            if let usersFetched = try sharedContext.executeFetchRequest(fetchRequest) as? [User] {
                assert(usersFetched.count < 2)
                if !usersFetched.isEmpty {
                    remoteUser = usersFetched.first!
                    if remoteUser!.isMe {
                        return nil
                    }
                }
            }
        } catch let userFetchError as NSError {
            print("\(userFetchError)")
            return nil
        }
        if remoteUser == nil {
            remoteUser = User(thisIsMe: false, userEmail: "", userPwd: "", displayName: socialName, context: sharedContext)
            CoreDataStackManager.sharedInstance.saveContext()
        }
        return remoteUser
    }
    
    func downloadSong(cell: SearchSongsCell, song: SongMixLite) {
        guard song.userDisplayName != currentUser.socialName else {
            return
        }
        guard !checkIfSongExists(song) else {
            return
        }
        guard let user = findOrCreateRemoteUserWithName(song.userDisplayName) else {
            return
        }
        let sharedContext = CoreDataStackManager.sharedInstance.managedObjectContext
        let song = SongMix(songInfo: song, context: sharedContext)
        song.artist = user
        CoreDataStackManager.sharedInstance.saveContext()
    }
}
extension SearchCommunityViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
        
    }
}