//
//  ChatViewController.swift
//  Flash Chat iOS13
//
//  Created by Angela Yu on 21/10/2019.
//  Copyright © 2019 Angela Yu. All rights reserved.
//

import UIKit
import Firebase

class ChatViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.register(UINib(nibName: K.cellNibName, bundle: nil), forCellReuseIdentifier: K.cellNibName)
        }
    }
    @IBOutlet weak var messageTextfield: UITextField!
    
    let db = Firestore.firestore()
    var messages: [Message] = []
    var animateChecker: Bool = false
    override func viewDidLoad() {
        super.viewDidLoad()
        title = K.appName
        setDelegates()
        navigationItem.hidesBackButton = true
        loadMessages()
    }
    
    
    
    @IBAction func sendPressed(_ sender: UIButton) {
        sendMessage()
    }
    @IBAction func logOutPressed(_ sender: UIBarButtonItem) {
        do {
            try Auth.auth().signOut()
            navigationController?.popToRootViewController(animated: true)
        } catch let signOutError as NSError {
            print ("Error signing out: %@", signOutError)
        }
    }
    
}

// MARK: - Table View Delegate

extension ChatViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return messages[indexPath.row].sender == Auth.auth().currentUser?.email
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if (editingStyle == .delete) {
            let time = messages[indexPath.row].time
            messages.remove(at: indexPath.row)
            let x = db.collection(K.FStore.collectionName).whereField("time", isEqualTo: time)
            x.getDocuments { (querySnapshot, error) in
                guard let snapshot = querySnapshot else {
                    print(error?.localizedDescription ?? "Error")
                    return
                }
                for snap in snapshot.documents {
                    snap.reference.delete()
                }
            }
            tableView.deleteRows(at: [indexPath], with: .automatic)
            
        }
    }
}

// MARK: - TableView Data Source

extension ChatViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellUnsafe = tableView.dequeueReusableCell(withIdentifier: K.cellNibName, for: indexPath) as? MessageCell
        guard let cell = cellUnsafe else {
            return UITableViewCell()
        }
        let message = messages[indexPath.row]
        cell.fillData(message)
        if Auth.auth().currentUser?.email == message.sender {
            cell.leftImage.isHidden = true
            cell.rightImage.isHidden = false
            cell.view.backgroundColor = UIColor(named: K.BrandColors.lightPurple)
        } else {
            cell.rightImage?.isHidden = true
            cell.leftImage.isHidden = false
            cell.view.backgroundColor = UIColor(named: K.BrandColors.purple)
        }
        return cell
    }
}

// MARK: - Text Field Delegate

extension ChatViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendMessage()
        return true
    }
}

// MARK: - Other functions

extension ChatViewController {
    func sendMessage(){
        if messageTextfield.text?.isEmpty == true {
            return
        }
        if let messageBody = messageTextfield.text, let senderMail = Auth.auth().currentUser?.email {
            let data: [String: Any] = [
                K.FStore.bodyField: messageBody,
                K.FStore.senderField: senderMail,
                "time": Date().timeIntervalSince1970
            ]
            db.collection(K.FStore.collectionName).addDocument(data: data) { (error) in
                if let e = error {
                    print("Error when uploading Message \(e)")
                } else {
                    DispatchQueue.main.async {
                        self.messageTextfield.text = ""
                    }
                }
                
            }
        } else {
            print("Error when uploading message")
        }
    }
    
    func loadMessages() {
        db.collection(K.FStore.collectionName).order(by: "time", descending: false).addSnapshotListener { (querySnapshot, error) in
            self.messages = []
            if let e = error {
                print("There is an error in loading messages \(e.localizedDescription)")
                return
            }
            if let documents = querySnapshot?.documents {
                for doc in documents {
                    let data = doc.data()
                    if let messageBody = data[K.FStore.bodyField] as? String,
                        let senderMail = data[K.FStore.senderField] as? String,
                        let time = data["time"] as? TimeInterval {
                        let message = Message(body: messageBody, sender: senderMail, time: time)
                        self.messages.append(message)
                    }
                }
                DispatchQueue.main.async {
                    
                    self.tableView.reloadData()
                    if !self.messages.isEmpty {
                        let indexPath = IndexPath(row: self.messages.count - 1 , section: 0)
                        self.tableView.scrollToRow(at: indexPath, at: .top, animated: self.animateChecker)
                    }
                    self.animateChecker = true
                }
            }
        }
    }
    
    func setDelegates() {
        tableView.dataSource = self
        messageTextfield.delegate = self
        tableView.delegate = self
        
    }
    
}
