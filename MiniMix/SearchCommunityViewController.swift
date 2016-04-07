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
    func playSong(cell: SearchSongsCell, song: SongMixDTO)
    func stopSong(cell: SearchSongsCell, song: SongMixDTO)
    func downloadSong(cell: SearchSongsCell, song: SongMixDTO)
}
//NOTE: this searches for the non-private uploaded mixes, but from OTHER users, not yourself.
//  If you want to re-synchronize your own mixes, that will be a sync button included somewhere on the SongListViewController
class SearchCommunityViewController: UIViewController {
    let CELL_ID = "SearchCell"
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    
    var currentUser: User!
    var currentResults = [SongMixDTO]()
    var currentlyPlayingCellRef: SearchSongsCell?
    var player: AVAudioPlayer?
    @IBOutlet weak var searchActivityIndicator: UIActivityIndicatorView!
    override func viewDidLoad() {
        super.viewDidLoad()
        hideKeyboardWhenTappedAround()
        
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
        searchActivityIndicator.hidden = true
        searchActivityIndicator.stopAnimating()
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
            dispatch_async(dispatch_get_main_queue()) {
                let vc = UIAlertController(title: title, message: msg, preferredStyle: .Alert)
                let okAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
                vc.addAction(okAction)
                self.presentViewController(vc, animated: true, completion: nil)
            }
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
        configureCell(cell, songSearchInfo: song)
        return cell
    }
    func configureCell(cell: SearchSongsCell, songSearchInfo song: SongMixDTO) {
        cell.delegate = self
        cell.songInfo = song
        cell.songArtistLabel.text = "artist: \(song.userDisplayName)"
        cell.genreLabel.text = song.genre
        cell.songNameLabel.text = song.name
        cell.setReadyToPlayUIState(true)
        cell.setDisabledStateForFailedMixPreviewDownload(false)
        cell.setBusyState(false)
    }
}

extension SearchCommunityViewController: UISearchBarDelegate {
    func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText == "" {
            currentResults = [SongMixDTO]()
            tableView.reloadData()
            return
        }
        setBusyState(true)
        let api = MiniMixCommunityAPI()
        api.verifyAuthTokenOrSignin(currentUser.email, password: currentUser.servicePassword) { success, message, error in
            guard success else {
                let msg = message ?? "Could not authenticate with the server"
                self.showAlertMsg("Search Failure", msg: msg)
                dispatch_async(dispatch_get_main_queue()) {
                    self.setBusyState(false)
                }
                return
            }
            api.searchSongs(searchText) { success, json, message, error in
                //search is a non-critical feature, no error display unless specific message received from server API
                guard error == nil else {
                    print("search error: \(error!.localizedDescription)")
                    dispatch_async(dispatch_get_main_queue()) {
                        self.setBusyState(false)
                    }
                    return
                }
                guard success else {
                    if let msg = message {
                        print(msg)
                        dispatch_async(dispatch_get_main_queue()) {
                            self.setBusyState(false)
                        }
                        self.showAlertMsg("Search Failure", msg: msg)
                    }
                    return
                }
                guard let jsonResponse = json else {
                    print("json response from search not valid")
                    dispatch_async(dispatch_get_main_queue()) {
                        self.setBusyState(false)
                    }
                    return
                }
                //print(jsonResponse)
                
                self.currentResults = jsonResponse.map() {
                    SongMixDTO(jsonDictionary: $0)
                }
                //print(self.currentResults.count)
                dispatch_async(dispatch_get_main_queue()) {
                    self.tableView.reloadData()
                    self.setBusyState(false)
                }
            }
        }
    }
    
    func setBusyState(isBusy: Bool) {
        searchActivityIndicator.hidden = !isBusy
        if isBusy {
            searchActivityIndicator.startAnimating()
        } else {
            searchActivityIndicator.stopAnimating()
        }
    }
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
}
extension SearchCommunityViewController: SongSearchPlaybackDelegate {
    
    func playSong(cell: SearchSongsCell, song: SongMixDTO) {
        if let existingPlay = player {
            existingPlay.stop()
        }
        if let playingCell = currentlyPlayingCellRef {
            playingCell.setReadyToPlayUIState(true)
            currentlyPlayingCellRef = nil
        }
        if let songUrl = song.mixFileUrl {
            //activity indicator for file download here..
            cell.setBusyState(true)
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
                let songDataTry = NSData(contentsOfURL: NSURL(string: songUrl)!)
                guard let songData = songDataTry else {
                    print("could not download song file to play")
                    dispatch_async(dispatch_get_main_queue()) {
                        cell.setBusyState(false)
                        cell.setDisabledStateForFailedMixPreviewDownload(true)
                    }
                    return
                }
                self.downloadAndStartPlayTask(downloadedSongData: songData, cell: cell)
            }
        } else {
            cell.setDisabledStateForFailedMixPreviewDownload(true)
        }
    }

    func downloadAndStartPlayTask(downloadedSongData songData: NSData, cell: SearchSongsCell) {
        do {
            try player = AVAudioPlayer(data: songData)
            player?.delegate = self
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(AVAudioSessionCategoryPlayback)
            if let player = player {
                player.prepareToPlay()
                player.play()
            }
            dispatch_async(dispatch_get_main_queue()) {
                cell.setReadyToPlayUIState(false)
                cell.setBusyState(false)
            }
            currentlyPlayingCellRef = cell
        } catch let playerErr as NSError {
            print("couldn't create player to play the mix: \(playerErr)")
            dispatch_async(dispatch_get_main_queue()) {
                cell.setBusyState(false)
                cell.setDisabledStateForFailedMixPreviewDownload(true)
            }
        }
    }
    
    func stopSong(cell: SearchSongsCell, song: SongMixDTO) {
        currentlyPlayingCellRef = nil
        if let player = player {
            player.stop()
        }
        cell.setReadyToPlayUIState(true)
    }
    
    func checkIfSongExists(songInfo: SongMixDTO) -> Bool {
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
        //fetchRequest.predicate = NSPredicate(format: "socialName == %@ AND isMe == %@", socialName, false)
        fetchRequest.predicate = NSPredicate(format: "socialName == %@", socialName)
        let sharedContext = CoreDataStackManager.sharedInstance.managedObjectContext
        var remoteUser: User?
        do {
            if let usersFetched = try sharedContext.executeFetchRequest(fetchRequest) as? [User] {
                assert(usersFetched.count < 2)
                if !usersFetched.isEmpty {
                    remoteUser = usersFetched.first!
//                    if remoteUser!.isMe {
//                        return nil
//                    }
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
    
    func downloadSong(cell: SearchSongsCell, song songDto: SongMixDTO) {
        guard !checkIfSongExists(songDto) else {
            return
        }
        dispatch_async(dispatch_get_main_queue()) {
            guard let user = self.findOrCreateRemoteUserWithName(songDto.userDisplayName) else {
                return
            }
            let sharedContext = CoreDataStackManager.sharedInstance.managedObjectContext
            let song = SongMix(songInfo: songDto, context: sharedContext)
            let songId = song.id
            let songName = song.name
            let mixUrl = song.mixFileUrl
            song.artist = user
            CoreDataStackManager.sharedInstance.saveContext()
            guard user.isMe else {
                return
            }
            let backgroundQueue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
            dispatch_async(backgroundQueue) {
                AudioCache.downSyncUserSongFile(songId, songName: songName, songFileRemoteUrl: mixUrl)
            }
            //TODO: missing track info...either 1. go get track info from another api call or 2. return track info for every search...
        }
        
    }
}



//dispatch_async(dispatch_get_main_queue()) {
//    let backgroundQueue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
//    let sharedContext = CoreDataStackManager.sharedInstance.managedObjectContext
//    let _ = songArray.map() {
//        if !mySongIdSet.contains($0[SongMix.Keys.ID] as! String) {
//            let song = SongMix(jsonDictionary: $0, context: sharedContext)
//            let songId = song.id
//            let songName = song.name
//            let mixUrl = song.mixFileUrl
//            dispatch_async(backgroundQueue) {
//                AudioCache.downSyncUserSongFile(songId, songName: songName, songFileRemoteUrl: mixUrl)
//            }
//            song.artist = self.currentUser
//            if let tracks = $0["audio_tracks"] as? [[String: AnyObject]] {
//                let _ = tracks.map() {
//                    let track = AudioTrack(dictionary: $0, context: sharedContext)
//                    track.song = song
//                    let trackId = track.id
//                    let trackUrl = track.trackFileUrl
//                    dispatch_async(backgroundQueue) {
//                        AudioCache.downSyncUserTrackFile(trackId, parentSongId: songId, trackRemoteUrl: trackUrl)
//                    }
//                }
//            }
//        }
//    }
//    CoreDataStackManager.sharedInstance.saveContext()
//    self.activityIndicator.hidden = true //NOTE: some files may be still uploading, but they are meant to be background...
//    self.activityIndicator.stopAnimating()
//}

















extension SearchCommunityViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
        if let cell = currentlyPlayingCellRef {
            currentlyPlayingCellRef = nil
            dispatch_async(dispatch_get_main_queue()) {
                cell.setBusyState(false)
                cell.setReadyToPlayUIState(true)
            }
        }
    }
}
extension SearchCommunityViewController {
    func hideKeyboardWhenTappedAround() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(SearchCommunityViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    
    func dismissKeyboard() {
        view.endEditing(true)
    }
}