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
    var postSigninCompletion: (() -> Void)?
    
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
            abort()
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
        fetchRequest.predicate = NSPredicate(format: "isMe == %@", true)
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
    }()
    
    
    //MARK: Action handlers...
    @IBAction func cancelAction() {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func registerAction() {
        guard let email = emailTextField.text where !email.isEmpty else {
            emailTextField.placeholder = "Please Enter Your Email!"
            return
        }
        guard let password = passwordTextField.text where !password.isEmpty else {
            passwordTextField.placeholder = "Please Enter Your Password!"
            return
        }
        guard let moniker = publicMonikerTextField.text where !moniker.isEmpty else {
            publicMonikerTextField.placeholder = "Please Enter Your Public Name!"
            return
        }
        let api = MiniMixCommunityAPI()
        api.registerNewUser(email, password: password, publicName: moniker) { success, jsonDictionary, message, error in
            //respond here to errors that are network and api related and when they should try again...
            if !success && error != nil {
                switch error!.code {
                case MiniMixCommunityAPI.ErrorCodes.API_ERROR:
                    var vmessage = message
                    if vmessage == nil {
                        vmessage = "api general error, please try again"
                    }
                    self.showAlert("API Error", message: vmessage!)
                    return
                case MiniMixCommunityAPI.ErrorCodes.NETWORK_ERROR:
                    print("general network error")
                    var vmessage = message
                    if vmessage == nil {
                        vmessage = "Network error, please try again"
                    }
                    self.showAlert("Network Error", message: vmessage!)
                    return
                default:
                    break
                }
            }
            var displayName = moniker
            if let returnedDisplayName = jsonDictionary![User.Keys.SocialName] as? String where returnedDisplayName != moniker {
                displayName = returnedDisplayName //Changing to what the API returned, this is because user is re-registering 
                                                //from different device and used different display/social name
            }
            //if success, want to make sure info gets saved and isRegistered is set an saved on the user
            dispatch_async(dispatch_get_main_queue()) {
                self.currentUser.isRegistered = success
                self.currentUser.email = success ? email : ""
                self.currentUser.servicePassword = success ? password : ""
                self.currentUser.socialName = success ? displayName : ""
                CoreDataStackManager.sharedInstance.saveContext()
                self.dismissViewControllerAnimated(true, completion: self.postSigninCompletion) //MARK: postSignup Completion...
            }
        }
    }
    //MARK: utility functions..
    func showAlert(title: String?, message: String) {
        if #available(iOS 8.0, *) {
            dispatch_async(dispatch_get_main_queue()) {
                let vc = UIAlertController(title: title, message: message, preferredStyle: .Alert)
                let okAction = UIAlertAction(title: "OK", style: .Default, handler: nil)
                vc.addAction(okAction)
                self.presentViewController(vc, animated: true, completion: nil)
            }
        } else {
            // Fallback on earlier versions
        }
        
        
        
    }
    
}
extension CommunityShareSignInViewController: UITextFieldDelegate {
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
}
