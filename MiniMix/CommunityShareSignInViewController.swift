//
//  CommunityShareSignInViewController.swift
//  MiniMix
//
//  Created by Jeff Newell on 3/11/16.
//  Copyright © 2016 Jeff Newell. All rights reserved.
//

import UIKit
import CoreData

class CommunityShareSignInViewController: UIViewController {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var publicMonikerTextField: UITextField!
    
    var currentUser: User!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        emailTextField.delegate = self
        passwordTextField.delegate = self
        publicMonikerTextField.delegate = self
        
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
            //initiate the user...
            currentUser = User(context: sharedContext)
            CoreDataStackManager.sharedInstance.saveContext()
        }
        //These should be blank, but just in case there's something in there
        emailTextField.text = currentUser.email
        passwordTextField.text = currentUser.servicePassword
        publicMonikerTextField.text = currentUser.socialName
    }
    
    //MARK: Core Data helper objects..
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance.managedObjectContext
    }
    lazy var fetchUserResultsController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "User")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "socialName", ascending: true)]
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
    }()
    
    
    //MARK: Action handlers...
    @IBAction func registerAction() {
        guard let email = emailTextField.text where !email.isEmpty else {
            
            return
        }
        guard let password = passwordTextField.text where !password.isEmpty else {

            return
        }
        guard let moniker = publicMonikerTextField.text where !moniker.isEmpty else {
            
            return
        }
        let api = MiniMixCommunityAPI()
        api.registerNewUser(email, password: password, publicName: moniker) { success, message, error in
            //TODO: respond here to errors that are network and api related and when they should try again...
            if !success && error != nil {
                switch error!.code {
                case MiniMixCommunityAPI.ErrorCodes.API_ERROR:
                    print("api general error")
                    return
                case MiniMixCommunityAPI.ErrorCodes.NETWORK_ERROR:
                    print("general network error")
                    return
                default:
                    break
                }
            }
            //if success, want to make sure info gets saved and isRegistered is set an saved on the user
            dispatch_async(dispatch_get_main_queue()) {
                self.currentUser.isRegistered = success
                self.currentUser.email = success ? email : ""
                self.currentUser.servicePassword = success ? password : ""
                self.currentUser.socialName = success ? moniker : ""
                CoreDataStackManager.sharedInstance.saveContext()
                self.dismissViewControllerAnimated(true, completion: nil)
            }
        }
    }
}
extension CommunityShareSignInViewController: UITextFieldDelegate {
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
}
