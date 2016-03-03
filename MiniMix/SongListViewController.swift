//
//  SongListViewController.swift
//  MiniMix
//
//  Created by Jeff Newell on 2/9/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import UIKit
import AVFoundation

protocol SongPlaybackDelegate {
    func playSong(song: SongMix)
    func stopSong(song: SongMix)
}

class SongListViewController: UIViewController {

    let CELL_ID = "cell"
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var shareButton: UIBarButtonItem!
    
    var songs = [SongMix]()
    var players = [AVAudioPlayer]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: CELL_ID)
    }
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        tableView.reloadData()
        shareButton.enabled = false
    }
    
    @IBAction func addNewSong() {
        let recordViewController = storyboard!.instantiateViewControllerWithIdentifier("SongMixerViewController") as! SongMixerViewController
        let newSong = SongMix(songName: "New Song")
        songs.append(newSong)
        recordViewController.song = newSong
        let songsInGenre = songs.filter { $0.genre == newSong.genre }
        let insertIndexPath = NSIndexPath(forRow: songsInGenre.count - 1, inSection: SongMix.genres.indexOf(newSong.genre)!)
        tableView.insertRowsAtIndexPaths([insertIndexPath], withRowAnimation: .Automatic)
        navigationController!.pushViewController(recordViewController, animated: true)
    }
    @IBAction func shareAction() {
        if let indexPath = tableView.indexPathForSelectedRow {
            let song = getSelectedSong(forIndexPath: indexPath)
            print("Shareing for song name: \(song.name)")
        }
    }
}
extension SongListViewController: UITableViewDataSource, UITableViewDelegate {
    //MARK: Data Source protocols
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let songsInGenre = songs.filter { $0.genre == SongMix.genres[section]}
        return songsInGenre.count
    }
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("SongCell") as! SongListingTableViewCell
        let song = getSelectedSong(forIndexPath: indexPath)
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
    func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        //three: Delete, ReMix, Edit, Share
        let delete = UITableViewRowAction(style: .Destructive, title: "Delete") { action, idxPath in
            self.deleteAction(idxPath)
        }
        let share = UITableViewRowAction(style: .Normal, title: "Share") { action, idxPath in
            self.shareAction(idxPath)
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
        let song = getSelectedSong(forIndexPath: indexPath)
        //TODO: this will go away when CoreData is added along with Cascade on the tracks relationship, plus a prepareForDelete on the track objects
        song.deleteTracks()
        if let deleteIndex = songs.indexOf(song) {
            songs.removeAtIndex(deleteIndex)
        }
        tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Automatic)
        //print("DELETING: \(song.name)")
    }
    func shareAction(indexPath: NSIndexPath) {
        let song = getSelectedSong(forIndexPath: indexPath)
        print("Sharing: \(song.name)")
    }
    func remixAction(indexPath: NSIndexPath) {
        let song = getSelectedSong(forIndexPath: indexPath)
        let recordViewController = storyboard!.instantiateViewControllerWithIdentifier("SongMixerViewController") as! SongMixerViewController
        recordViewController.song = song
        navigationController!.pushViewController(recordViewController, animated: true)
    }
    func editinfoAction(indexPath: NSIndexPath) {
        let song = getSelectedSong(forIndexPath: indexPath)
        let songInfoViewController = storyboard?.instantiateViewControllerWithIdentifier("SongInfoViewController") as! SongInfoViewController
        songInfoViewController.song = song
        presentViewController(songInfoViewController, animated: true, completion: nil)
    }
    
    func getSelectedSong(forIndexPath indexPath: NSIndexPath) -> SongMix {
        let songsInGenre = songs.filter { $0.genre == SongMix.genres[indexPath.section]}
        return songsInGenre[indexPath.row]
    }
}
extension SongListViewController: SongPlaybackDelegate {
    func playSong(song: SongMix) {
        playMixNaiveImplementation(song)
    }
    func stopSong(song: SongMix) {
        
    }
    
    func playMixNaiveImplementation(song: SongMix) {
        players.removeAll()
        var path: NSURL
        for track in song.tracks {
            do {
                path = AudioCache.trackPath(track, parentSong: song)
                let player = try AVAudioPlayer(contentsOfURL: path)
                player.volume = track.isMuted ? 0.0 : track.mixVolume
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