//
//  SongInfoViewController.swift
//  MiniMix
//
//  Created by Jeff Newell on 2/9/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import UIKit
import CoreData

//TODO: Add a Floating Star Review control to this
//      I have an open source option: 
//   https://github.com/glenyi/FloatRatingView
//    which I cloned to my desktop...lets roll it in

class SongInfoViewController: UIViewController {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var picker: UIPickerView!
    @IBOutlet weak var songNameTextField: UITextField!
    @IBOutlet weak var songDecriptionTextView: UITextView!
    @IBOutlet weak var songStarRatings: FloatRatingView!
    @IBOutlet weak var keepPrivateToggle: UISwitch!
    
    var tapGestureRecognizer: UITapGestureRecognizer!
    
    var song: SongMix?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        picker.delegate = self
        picker.dataSource = self
        songNameTextField.delegate = self
        songDecriptionTextView.delegate = self
        songStarRatings.delegate = self
        
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapWithinScroll(_:)))
        tapGestureRecognizer.numberOfTapsRequired = 1
    }
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        scrollView.addGestureRecognizer(tapGestureRecognizer)
        if let song = song {
            songNameTextField!.text = song.name
            if let rating = song.rating {
                songStarRatings!.rating = Float(rating)
            }
            songDecriptionTextView.text = song.songDescription
            if let row = SongMix.genres.indexOf(song.genre) {
                picker.selectRow(row, inComponent: 0, animated: true)
            }
            keepPrivateToggle.on = song.keepPrivate
        }
    }
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        scrollView.removeGestureRecognizer(tapGestureRecognizer)
    }
    func tapWithinScroll(recognizer: UITapGestureRecognizer) {
        view.endEditing(true)
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    //MARK: Fetched Results Controllers And Core Data helper objects
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance.managedObjectContext
    }
//    lazy var userFetchedResultsController: NSFetchedResultsController = {
//        let fetchRequest = NSFetchRequest(entityName: "User")
//        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "socialName", ascending: true)]
//        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
//            managedObjectContext: self.sharedContext,
//            sectionNameKeyPath: nil,
//            cacheName: nil)
//        
//        return fetchedResultsController
//    }()
//    
//    lazy var songsFetchedResultsControllerForUser: NSFetchedResultsController = {
//        let fetchRequest = NSFetchRequest(entityName: "SongMix")
//        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
//        fetchRequest.predicate = NSPredicate(format: "artist == %@", self.currentUser)
//        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
//            managedObjectContext: self.sharedContext,
//            sectionNameKeyPath: nil,
//            cacheName: nil)
//        
//        return fetchedResultsController
//    }()


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    @IBAction func exitModal(sender: UIBarButtonItem) {
        //TODO: save data
        if let song = song {
            song.name = songNameTextField.text!
            song.genre = SongMix.genres[picker.selectedRowInComponent(0)]
            song.userInitialized = true
            song.rating = songStarRatings.rating
            song.songDescription = songDecriptionTextView.text
            song.keepPrivate = keepPrivateToggle.on
            //TODO: send of a update_song api call task
            //WARNING: TODO: this maybe would be better in a delegate back to the SongList controller to do this..
            CoreDataStackManager.sharedInstance.saveContext()
        }
        //
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}

extension SongInfoViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return SongMix.genres.count
    }
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return SongMix.genres[row]
    }
}
extension SongInfoViewController: UITextFieldDelegate, UITextViewDelegate {
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    func textView(textView: UITextView, shouldChangeTextInRange range: NSRange, replacementText text: String) -> Bool {
        if( text == "\n") {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
}

extension SongInfoViewController: FloatRatingViewDelegate {
    func floatRatingView(ratingView: FloatRatingView, didUpdate rating: Float) {
        if let song = song {
            song.rating = songStarRatings.rating
        }
    }
}