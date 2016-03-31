//
//  SongMixerViewController.swift
//  MiniMix
//
//  Created by Jeff Newell on 2/9/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import UIKit
import AVFoundation
import CoreData

protocol TrackControllerDelegate {
    func recordTrack(track: AudioTrack, completion: (success: Bool)->Void)
    func stopRecord(track: AudioTrack, completion: (success: Bool)->Void)
    func playTrack(track: AudioTrack, atVolume volume: Float)
    func stopTrackPlayback(track: AudioTrack)
    func changeTrackVolumne(track: AudioTrack, newVolume volume: Float)
    func muteTrackPlayback(track: AudioTrack, doMute: Bool)
    func eraseTrackRecording(track: AudioTrack, completion: (success: Bool)->Void)
}
protocol MasterPlaybackControllerDelegate {
    func playMix()
}

class SongMixerViewController: UITableViewController {
    static let MAX_TRACK_SECONDS = 60
    let WARNING_INTERVAL_SECONDS = 5
    let MAX_TRACKS = 6
    
    let TRACKS_SECTION = 0
    let MASTER_SECTION = 1
    
    var song: SongMix! {
        didSet {
            dataIsDirty = false
        }
    }
    var dataIsDirty = false
    //var mixTracks = [AudioTrack]()
    var audioRecorder: AVAudioRecorder!
    var currentRecordingTrackRef: AudioTrack? //WARNING: I don't like these..
    var currentRecordingCell: TrackTableViewCell? //    got to make sure this is safe: using for Progess updates And StopRecord notify
    var players = [AVAudioPlayer]()
    var recordProgressTimer: NSTimer?
    var recordSeconds = 0
    var recordTimer: NSTimer?
    var finalCountdownTimer: NSTimer?
    var finalCountdown = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            try tracksFetchedResultsControllerForSong.performFetch()
        } catch {
            //TODO: do the appropriate thing
        }
        tracksFetchedResultsControllerForSong.delegate = self
        
        if let songs = tracksFetchedResultsControllerForSong.fetchedObjects {
            if songs.isEmpty {
                let track = AudioTrack(trackName: "Audio 1", trackType: AudioTrack.TrackType.MIX, trackOrder: 0, insertIntoManagedObjectContext: sharedContext)
                track.song = song
                CoreDataStackManager.sharedInstance.saveContext()
            }
        }
        // Do any additional setup after loading the view.
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: #selector(SongMixerViewController.addTrack))
        navigationItem.hidesBackButton = true
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: " \u{2329} Back", style: .Plain, target: self, action: #selector(SongMixerViewController.back))
    }
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        print("OOPS!! MEMORY WARNING...")
    }
    
    //MARK: Fetched Results Controllers And Core Data helper objects
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance.managedObjectContext
    }
    
    lazy var tracksFetchedResultsControllerForSong: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "AudioTrack")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "displayOrder", ascending: true)]
        fetchRequest.predicate = NSPredicate(format: "song == %@", self.song)
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
    }()
    
    // MARK: helper functions
    func back() {
        //First time the song mix is created, AFTER recordings done, back to the Info Form
        //   after that, just go back to the list
        if dataIsDirty {
            song.version += 1
            print("SONG VERSION CHANGED from \(song.version - 1) to \(song.version) (\(song.name))")
            dataIsDirty = false
            let backgroundQueue = dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
            dispatch_async(backgroundQueue) {
                AudioHelpers.createSongMixFile(self.song) { success in
                    if !success {
                        print("New Mix file failed")
                    }
                }
            }
        }
        CoreDataStackManager.sharedInstance.saveContext()
        
        if !song!.userInitialized {
            let songInfoViewController = storyboard?.instantiateViewControllerWithIdentifier("SongInfoViewController") as! SongInfoViewController
            songInfoViewController.song = song
            presentViewController(songInfoViewController, animated: true) {
                self.navigationController?.popViewControllerAnimated(true)
            }
        } else {
            navigationController?.popViewControllerAnimated(true)
        }
    }
    
    lazy var applicationDocumentsDirectory: NSURL = {
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1]
    }()
    
    // MARK: Actions
    func addTrack() {
        guard let fetchedTracks = tracksFetchedResultsControllerForSong.fetchedObjects as? [AudioTrack] else {
            print("Could not fetch tracks, unable to add another track")
            return
        }
        let trackCount = fetchedTracks.count
        if trackCount < MAX_TRACKS {
            let newTrack = AudioTrack(trackName: "Audio \(trackCount + 1)", trackType: AudioTrack.TrackType.MIX, trackOrder: Int32(trackCount), insertIntoManagedObjectContext: sharedContext)
            newTrack.song = song
            dataIsDirty = true
            CoreDataStackManager.sharedInstance.saveContext()
        }
    }
    

    // MARK: TableView delegates
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == MASTER_SECTION {
            return 1
        } else {
            if let items = tracksFetchedResultsControllerForSong.fetchedObjects {
                return items.count
            } else {
                return 0
            }
        }
    }
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == MASTER_SECTION ? "MASTER TRACK" : "MIX TRACKS"
    }
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return indexPath.section == MASTER_SECTION ? 116 : 136
    }
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        var returnCell: UITableViewCell?
        if indexPath.section == TRACKS_SECTION {
            let cell = tableView.dequeueReusableCellWithIdentifier("TrackCell") as! TrackTableViewCell
            cell.delegate = self
            let track = tracksFetchedResultsControllerForSong.objectAtIndexPath(indexPath) as! AudioTrack
            cell.track = track
            cell.trackNameTextView.text = track.name
            cell.volumeSlider.value = Float(track.mixVolume)
            //print("track of song: \(track.song!.name) track name: \(track.name) at \(track.trackFileUrl)")
            returnCell = cell
        } else {
            let cell = tableView.dequeueReusableCellWithIdentifier("MasterCell") as! MasterTableViewCell
            cell.delegate = self
            returnCell = cell
        }
        return returnCell!
    }
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        //EMPTY...handled by the actions below
    }
    @available(iOS 8.0, *)
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        if indexPath.section == MASTER_SECTION {
            return []
        } else {
            let delete = UITableViewRowAction(style: .Destructive, title: "Delete") { action, idxPath in
                let cell = self.tableView.cellForRowAtIndexPath(idxPath) as! TrackTableViewCell
                guard let track = cell.track else {
                    return
                }
                self.dataIsDirty = true
                //delete audio file : TODO: delete the code below that is commented out...CoreData will take care of all that
                dispatch_async(dispatch_get_main_queue()) {
                    self.sharedContext.deleteObject(track)
                    CoreDataStackManager.sharedInstance.saveContext()
                }
            }
            return [delete]
        }
    }
}

extension SongMixerViewController: TrackControllerDelegate {
    func recordLimitWarning() {
        print("\(WARNING_INTERVAL_SECONDS) left to record")
        recordTimer?.invalidate()
        finalCountdownTimer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: #selector(SongMixerViewController.finalRecordCountdown), userInfo: nil, repeats: true)
        finalCountdown = WARNING_INTERVAL_SECONDS
    }
    func finalRecordCountdown() {
        finalCountdown-=1
        if finalCountdown <= 0 {
            finalCountdownTimer?.invalidate()
            stopRecord(currentRecordingTrackRef!) { success in
                self.view.alpha = 1.0
            }
        } else {
            //re-flash warning
            view.alpha = (view.alpha == 1.0 ? 0.5 : 1.0)
        }
    }
    func recordProgress() {
        recordSeconds+=1
        currentRecordingTrackRef?.lengthSeconds = Double(recordSeconds)
        if let cell = currentRecordingCell {
            cell.trackProgressUpdate()
        }
    }
    
    func recordTrack(track: AudioTrack, completion: (success: Bool) -> Void) {
        //NOTE: i am setting the dataIsDirty flag after the recording stops and is successful
        print("recording: \(NSDate())")
        currentRecordingTrackRef = track
        let rowCount = tableView.numberOfRowsInSection(TRACKS_SECTION)
        for row in 0..<rowCount {
            if let cell =  tableView.cellForRowAtIndexPath(NSIndexPath(forRow: row, inSection: TRACKS_SECTION)) as? TrackTableViewCell {
                if cell.track === currentRecordingTrackRef {
                    currentRecordingCell  = cell
                    break
                }
            }
        }
        //need to set a timer...
        recordTimer = NSTimer.scheduledTimerWithTimeInterval(NSTimeInterval(SongMixerViewController.MAX_TRACK_SECONDS - WARNING_INTERVAL_SECONDS), target: self, selector: #selector(recordLimitWarning), userInfo: nil, repeats: false)
        recordProgressTimer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: #selector(recordProgress), userInfo: nil, repeats: true)
        recordSeconds = 0
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(AVAudioSessionCategoryPlayAndRecord)
            try session.setActive(true)
        } catch let error as NSError {
            currentRecordingTrackRef = nil
            print("could not record track, session create error: \(error.localizedDescription)")
            completion(success: false)
            return
        }
        //create subdirectory in Documents for the SONG, the tracks and mix go in there...
        if !NSFileManager.defaultManager().fileExistsAtPath(AudioCache.songDirectory(song!)) {
            do {
                try NSFileManager.defaultManager().createDirectoryAtPath(AudioCache.songDirectory(song!), withIntermediateDirectories: true, attributes: nil)
            } catch let error as NSError {
                currentRecordingTrackRef = nil
                print("could not create song directory, not able to prepare for recording: \(error.localizedDescription)")
                completion(success: false)
                return
            }
        }
        //get ready to record!!
        let recordSettings = [String: AnyObject]()
//            AVFormatIDKey: NSNumber(unsignedInt:kAudioFormatAppleLossless),
//            AVEncoderAudioQualityKey : AVAudioQuality.Min.rawValue,
//            AVEncoderBitRateKey : 320000,
//            AVNumberOfChannelsKey: 1,
//            AVSampleRateKey : 44100.0
//        ]
        do {
            audioRecorder = try AVAudioRecorder(URL: AudioCache.trackPath(track, parentSong: song!), settings: recordSettings)
        } catch let error as NSError {
            currentRecordingTrackRef = nil
            print("record error: \(error.localizedDescription)")
            completion(success: false)
            return
        }
        audioRecorder.prepareToRecord()
        //GET Playback tracks ready!
        players.removeAll()
        let otherTracks = song.tracks.filter { $0.id != track.id }
        for track in otherTracks {
            do {
                let player = try AVAudioPlayer(contentsOfURL: AudioCache.trackPath(track, parentSong: song!))
                player.volume = track.isMuted ? 0.0 : Float(track.mixVolume)
                players.append(player)
            } catch let error as NSError {
                print("Could not create player for track(\(track.name): \(error)")
            }
        }
        for player in players {
            player.prepareToPlay()
        }
        audioRecorder.record()
        for player in players {
            player.play()
        }
        completion(success: true)
    }
   
    func stopRecord(track: AudioTrack, completion: (success: Bool) -> Void) {
        defer {
            //nil out the ref to currentCell and currentTrack being recorded to
            currentRecordingTrackRef = nil
            if let cell =  currentRecordingCell {
                cell.setStopRecordUIState()
            }
            currentRecordingCell = nil
        }
        
        track.lengthSeconds = Double(recordSeconds)
        recordTimer?.invalidate()
        finalCountdownTimer?.invalidate()
        recordProgressTimer?.invalidate()
        
        guard let audioRecorder = audioRecorder else {
            completion(success: false)
            return
        }
        audioRecorder.stop()
        for player in players {
            player.stop()
        }
        players.removeAll()
    
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false)
        } catch {}
        
        if let recordPath = audioRecorder.url.path {
            if !NSFileManager.defaultManager().fileExistsAtPath(recordPath) {
                //print("track path found no file: \(recordPath)")
                completion(success: false)
            }
        }
        track.hasRecordedFile = true
        dataIsDirty = true
        dispatch_async(dispatch_get_main_queue()) {
            CoreDataStackManager.sharedInstance.saveContext()
        }
        completion(success: true)
    }
    func eraseTrackRecording(track: AudioTrack, completion: (success: Bool) -> Void) {
        do {
            try NSFileManager.defaultManager().removeItemAtPath(AudioCache.trackPath(track, parentSong: song).path!)
        } catch {}
        
        dispatch_async(dispatch_get_main_queue()) {
            track.hasRecordedFile = false
            track.lengthSeconds = 0.0
            CoreDataStackManager.sharedInstance.saveContext()
        }
        dataIsDirty = true
        completion(success: true)
    }
    func stopTrackPlayback(track: AudioTrack) {
        if let player = players.filter( { $0.url! == AudioCache.trackPath(track, parentSong: song!) } ).first {
            player.stop()
        } else {
            print("couldnt find the player of the track to STOP")
        }
    }
    func playTrack(track: AudioTrack, atVolume volume: Float) {
        players.removeAll()
        var path: NSURL
        do {
            path = AudioCache.trackPath(track, parentSong: song!)
            let player = try AVAudioPlayer(contentsOfURL: path)
            player.volume = track.isMuted ? 0.0 : Float(track.mixVolume)
            player.delegate = self
            players.append(player)
        } catch let error as NSError {
            print("could not create audio player for audio file at \(path.path!)\n  \(error.localizedDescription)")
        }
        for player in players {
            player.play()
        }
        

    }
    func changeTrackVolumne(track: AudioTrack, newVolume volume: Float) {
        //TODO: this is problematic..heavy processing here for every minute change in the slider
        //  need to rework some of this..
        track.mixVolume = volume
        if let player = players.filter( { $0.url! == AudioCache.trackPath(track, parentSong: song!) } ).first {
            player.volume = Float(track.mixVolume)
            dataIsDirty = true
        } 
    }
    func muteTrackPlayback(track: AudioTrack, doMute: Bool) {
        track.isMuted = doMute
        if let player = players.filter( { $0.url! == AudioCache.trackPath(track, parentSong: song!) } ).first {
            player.volume = doMute ? 0.0 : Float(track.mixVolume)
        } else {
            print("couldnt find the player of the track to MUTE")
        }
    }
    
}
extension SongMixerViewController: MasterPlaybackControllerDelegate {
    func playMix() {
        print("..playing the mix..")
        playMixNaiveImplementation()
    }
    
    func playMixNaiveImplementation() {
        players.removeAll()
        var path: NSURL
        for track in song.tracks {
            do {
                path = AudioCache.trackPath(track, parentSong: song!)
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
            player.play() //actually, using playAtTime(...) might help in synchronization here...
        }
    }
//    func songDirectory(song: SongMix) -> String {
//        return applicationDocumentsDirectory.URLByAppendingPathComponent(song.id.UUIDString).path!
//    }
//    func trackPath(track: AudioTrack, parentSong song: SongMix) -> NSURL {
//        //let pathComponents = [applicationDocumentsDirectory.path!, song.id.UUIDString, track.name]
//        let pathComponents = [songDirectory(song), "\(track.id.UUIDString).caf"]
//        return NSURL.fileURLWithPathComponents(pathComponents)!
//    }
}
extension SongMixerViewController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
        for p in players {
            if p.playing {
                return
            }
        }
        //TODO: No more players playing, so set the track playback button back to "ready to play" state
        for row in 0..<tableView.numberOfRowsInSection(TRACKS_SECTION) {
            if let cell = tableView.cellForRowAtIndexPath(NSIndexPath(forRow: row, inSection: TRACKS_SECTION)) as? TrackTableViewCell {
                cell.setTrackPlayButtonsToReadyToPlayState()
            }
        }
        //tableView.cellForRowAtIndexPath(<#T##indexPath: NSIndexPath##NSIndexPath#>)
    }
}
extension SongMixerViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        tableView.beginUpdates()
    }
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        tableView.endUpdates()
    }
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        
        switch type {
        case .Insert:
            if newIndexPath!.section == TRACKS_SECTION {
                tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Automatic)
//                let newIndexPath = NSIndexPath(forRow: trackCount, inSection: TRACKS_SECTION)
//                tableView.insertRowsAtIndexPaths([newIndexPath], withRowAnimation: .Automatic)
                let trackCount = tracksFetchedResultsControllerForSong.fetchedObjects!.count
                navigationItem.rightBarButtonItem?.enabled = (trackCount < MAX_TRACKS)
            }
            
        case .Delete:
            if indexPath!.section == TRACKS_SECTION {
                tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Automatic)
            }
        case .Update:
            if indexPath!.section == TRACKS_SECTION {
                //_ = tableView.cellForRowAtIndexPath(indexPath!) as! TrackTableViewCell
                //let actor = controller.objectAtIndexPath(indexPath!) as! Person
                //self.configureCell(cell, withActor: actor)
            }
        case .Move:
            print("moving cell")
//            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
//            tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
        }
    }
    
    
}