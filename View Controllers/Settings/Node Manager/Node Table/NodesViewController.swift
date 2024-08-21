//
//  NodesViewController.swift
//  BitSense
//
//  Created by Peter on 29/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class NodesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UINavigationControllerDelegate {
    
    private var nodeArray = [[String:Any]]()
    private var selectedIndex = Int()
    private let ud = UserDefaults.standard
    private var addButton = UIBarButtonItem()
    private var editButton = UIBarButtonItem()
    private var now: Date = .now
    private var firstTap: Date?
    private var lastTap: Date?
    private var authenticated = false
    
    @IBOutlet var nodeTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.delegate = self
        nodeTable.tableFooterView = UIView(frame: .zero)
        addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNode))
        editButton = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(editNodes))
        addButton.tintColor = .systemTeal
        editButton.tintColor = .systemTeal
        self.navigationItem.setRightBarButtonItems([addButton, editButton], animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        getNodes()
    }
    
    func getNodes() {
        nodeArray.removeAll()
        CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
            guard let self = self else { return }
            
            guard let nodes = nodes else {
                showAlert(vc: self, title: "", message: "Error getting nodes from core data.")
                return
            }
            
            self.nodeArray.removeAll()
            
            for node in nodes {
                let nodeStr = NodeStruct(dictionary: node)
                self.nodeArray.append(node)
            }
            
            self.reloadNodeTable()
            
            if self.nodeArray.count == 0 {
                self.addNodePrompt()
            }
        }
    }
    
    private func reloadNodeTable() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.nodeTable.reloadData()
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return nodeArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    private func decryptedValue(_ encryptedValue: Data) -> String {
        guard let decrypted = Crypto.decrypt(encryptedValue) else { return "" }
        
        return decrypted.utf8String ?? ""
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "node", for: indexPath)
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        
        let label = cell.viewWithTag(1) as! UILabel
        let isActive = cell.viewWithTag(2) as! UISwitch
        let background = cell.viewWithTag(3)!
        let icon = cell.viewWithTag(4) as! UIImageView
        let button = cell.viewWithTag(5) as! UIButton
        
        button.restorationIdentifier = "\(indexPath.section)"
        button.addTarget(self, action: #selector(editNode(_:)), for: .touchUpInside)
        
        background.clipsToBounds = true
        background.layer.cornerRadius = 8
        
        let nodeStruct = NodeStruct(dictionary: nodeArray[indexPath.section])
        label.text = nodeStruct.label
        isActive.isOn = nodeArray[indexPath.section]["isActive"] as? Bool ?? false
        isActive.restorationIdentifier = "\(indexPath.section)"
        isActive.addTarget(self, action: #selector(setActiveNow(_:)), for: .touchUpInside)
        
        if !isActive.isOn {
            label.textColor = .darkGray
        } else {
            label.textColor = .white
        }
        
        icon.tintColor = .white
        
        icon.image = UIImage(systemName: "link")
        background.backgroundColor = .systemBlue
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
    @objc func editNode(_ sender: UIButton) {
        func editNow() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.firstTap = .now
                guard let id = sender.restorationIdentifier, let section = Int(id) else { return }
                self.selectedIndex = section
                self.performSegue(withIdentifier: "updateNode", sender: self)
            }
        }
        
        if let firstTap = firstTap {
            if firstTap.timeIntervalSinceNow < -2.0 {
                editNow()
            }
        } else {
            editNow()
        }
    }
    
    @objc func editNodes() {
        nodeTable.setEditing(!nodeTable.isEditing, animated: true)
        
        if nodeTable.isEditing {
            editButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(editNodes))
        } else {
            editButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(editNodes))
        }
        
        addButton.tintColor = .systemTeal
        editButton.tintColor = .systemTeal
        
        self.navigationItem.setRightBarButtonItems([addButton, editButton], animated: true)
    }
    
    private func deleteNode(nodeId: UUID, indexPath: IndexPath) {
        CoreDataService.deleteEntity(id: nodeId, entityName: .newNodes) { [weak self] success in
            guard let self = self else { return }
            if success {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    nodeArray.remove(at: indexPath.section)
                    nodeTable.deleteSections(IndexSet.init(arrayLiteral: indexPath.section), with: .fade)
                }
            } else {
                showAlert(vc: self, title: "", message: "We had an error trying to delete that node")
            }
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCell.EditingStyle.delete {
            let node = NodeStruct(dictionary: nodeArray[indexPath.section])
            deleteNode(nodeId: node.id, indexPath: indexPath)
        }
    }
    
    @objc func setActiveNow(_ sender: UISwitch) {        
        impact()
        
        let restId = sender.restorationIdentifier ?? ""
        let index = Int(restId) ?? 10000
        
        guard let selectedCell = nodeTable.cellForRow(at: IndexPath.init(row: 0, section: index)) else {
            return
        }
        
        let selectedSwitch = selectedCell.viewWithTag(2) as! UISwitch
        let nodeStr = NodeStruct(dictionary: nodeArray[index])
        
        if index < nodeArray.count {
            
            CoreDataService.update(id: nodeStr.id, keyToUpdate: "isActive", newValue: selectedSwitch.isOn, entity: .newNodes) { [unowned vc = self] success in
                if success {
                    if vc.nodeArray.count == 1 {
                        vc.reloadTable()
                    }
                                        
                } else {
                    showAlert(vc: self, title: "", message: "Error updating node.")
                }
            }
            
            if nodeArray.count > 1 {
                for (i, node) in nodeArray.enumerated() {
                    if i != index {
                        let str = NodeStruct(dictionary: node)
                        
                        if str.id != nodeStr.id {
                            CoreDataService.update(id: str.id, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { _ in }
                        }
                    }
                    
                    if i + 1 == nodeArray.count {
                        CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
                            if nodes != nil {
                                DispatchQueue.main.async { [unowned vc = self] in
                                    vc.nodeArray.removeAll()
                                    for node in nodes! {
                                        let str = NodeStruct(dictionary: node)
                                        vc.nodeArray.append(node)
                                    }
                                    vc.nodeTable.reloadData()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func reloadTable() {
        CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
            if nodes != nil {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.nodeArray.removeAll()
                    for node in nodes! {
                        let ns = NodeStruct(dictionary: node)
                        vc.nodeArray.append(node)
                    }
                    vc.nodeTable.reloadData()
                }
            } else {
                showAlert(vc: self, title: "", message: "Error getting nodes from core data.")
            }
        }
    }
    
    private func reduced(label: String) -> String {
        var first = String(label.prefix(25))
        if label.count > 25 {
            first += "..."
        }
        return "\(first)"
    }
    
    private func addNodePrompt() {
        self.segueToAddNodeManually()
//        DispatchQueue.main.async { [weak self] in
//            guard let self = self else { return }
//            
//            self.isLightning = false
//            self.isJoinMarket = true
//            self.isBitcoinCore = false
//            self.segueToAddNodeManually()
//        }
    }
    
    @IBAction func addNode(_ sender: Any) {
        //addNodePrompt()
        self.segueToAddNodeManually()
    }
        
    private func segueToAddNodeManually() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToAddBitcoinCoreNode", sender: vc)
        }
    }
    
    private func segueToScanNode() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToScanAddNode", sender: vc)
        }
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "updateNode" {
            if let vc = segue.destination as? NodeDetailViewController {
                vc.selectedNode = self.nodeArray[selectedIndex]
                vc.createNew = false
            }
        }
        
        if segue.identifier == "segueToAddBitcoinCoreNode" {
            if let vc = segue.destination as? NodeDetailViewController {
                vc.createNew = true
            }
        }
    }
}


