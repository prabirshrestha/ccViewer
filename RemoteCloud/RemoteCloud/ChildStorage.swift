//
//  ChildStorage.swift
//  RemoteCloud
//
//  Created by rei6 on 2019/03/13.
//  Copyright © 2019 lithium03. All rights reserved.
//

import Foundation
import CoreData
import os.log

class ViewControllerRoot: UIViewController, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate {
    var tableView: UITableView!
    var activityIndicator: UIActivityIndicatorView!
    var storages: [String] = []
    
    var onCancel: (()->Void)!
    var onDone: ((String, String)->Void)!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Select base path"

        tableView = UITableView()
        tableView.frame = view.frame
        tableView.backgroundColor = UIColor(red: 1.0, green: 0.9, blue: 0.9, alpha: 1.0)

        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.tableFooterView = UIView(frame: .zero)
        
        view.addSubview(tableView)
        
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonDidTap))
        
        navigationItem.rightBarButtonItem = cancelButton
        
        activityIndicator = UIActivityIndicatorView()
        activityIndicator.center = tableView.center
        activityIndicator.style = .whiteLarge
        activityIndicator.color = .black
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        
        navigationItem.hidesBackButton = true
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return storages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        let name = storages[indexPath.row]
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.lineBreakMode = .byWordWrapping
        cell.textLabel?.text = name
        cell.backgroundColor = UIColor(red: 1.0, green: 0.9, blue: 0.9, alpha: 1.0)
        if let service = CloudFactory.shared[name]?.getStorageType() {
            let image = CloudFactory.shared.getIcon(service: service)
            cell.imageView?.image = image
        }

        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: true)
        
        activityIndicator.startAnimating()
        let name = storages[indexPath.row]
        CloudFactory.shared[name]?.list(fileId: "") {
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                let next = ViewControllerItem()
                next.rootPath = "\(name):/"
                next.rootFileId = ""
                next.storageName = name
                next.onCancel = self.onCancel
                next.onDone = self.onDone
                self.navigationController?.pushViewController(next, animated: true)
            }
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        activityIndicator.center = tableView.center
        activityIndicator.center.y = tableView.bounds.size.height/2 + tableView.contentOffset.y
    }
    
    @objc func cancelButtonDidTap(_ sender: UIBarButtonItem)
    {
        onCancel()
    }
}

class ViewControllerItem: UIViewController, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate {
    var tableView: UITableView!
    var activityIndicator: UIActivityIndicatorView!
    var refreshControl: UIRefreshControl!
    
    var rootPath: String = ""
    var rootFileId: String = ""
    var storageName: String = ""

    var onCancel: (()->Void)!
    var onDone: ((String, String)->Void)!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView = UITableView()
        tableView.frame = view.frame
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.tableFooterView = UIView(frame: .zero)
        
        view.addSubview(tableView)
        
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonDidTap))
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneButtonDidTap))

        navigationItem.rightBarButtonItems = [doneButton, cancelButton]
        
        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        
        activityIndicator = UIActivityIndicatorView()
        activityIndicator.center = tableView.center
        activityIndicator.style = .whiteLarge
        activityIndicator.color = .black
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)

        self.title = rootPath
    }
    
    @objc func refresh() {
        CloudFactory.shared[storageName]?.list(fileId: rootFileId) {
            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.refreshControl.endRefreshing()
            }
        }
    }
    

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let result = CloudFactory.shared.data.listData(storage: storageName, parentID: rootFileId)
        return result.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        // Configure the cell...
        
        let result = CloudFactory.shared.data.listData(storage: storageName, parentID: rootFileId)
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.lineBreakMode = .byWordWrapping
        cell.textLabel?.text = result[indexPath.row].name
        
        if result[indexPath.row].folder {
            cell.accessoryType = .disclosureIndicator
            var tStr = ""
            if result[indexPath.row].mdate != nil {
                let f = DateFormatter()
                f.dateStyle = .medium
                f.timeStyle = .medium
                tStr = f.string(from: result[indexPath.row].mdate!)
            }
            cell.detailTextLabel?.text = "\(tStr)\tfolder"
            cell.backgroundColor = UIColor.init(red: 1.0, green: 1.0, blue: 0.9, alpha: 1.0)
        }
        else {
            cell.accessoryType = .none
            var tStr = ""
            if result[indexPath.row].mdate != nil {
                let f = DateFormatter()
                f.dateStyle = .medium
                f.timeStyle = .medium
                tStr = f.string(from: result[indexPath.row].mdate!)
            }
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = ","
            formatter.groupingSize = 3
            let sStr = formatter.string(from: result[indexPath.row].size as NSNumber) ?? "0"
            cell.detailTextLabel?.numberOfLines = 0
            cell.detailTextLabel?.lineBreakMode = .byWordWrapping
            cell.detailTextLabel?.text = "\(tStr)\t\(sStr) bytes"
            cell.backgroundColor = .white
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: true)
        
        let result = CloudFactory.shared.data.listData(storage: storageName, parentID: rootFileId)
        if result[indexPath.row].folder {
            if let path = result[indexPath.row].path {
                let next = ViewControllerItem()
                
                next.rootPath = path
                next.rootFileId = result[indexPath.row].id ?? ""
                next.storageName = storageName
                next.onCancel = onCancel
                next.onDone = onDone
                let newroot = CloudFactory.shared.data.listData(storage: storageName, parentID: next.rootFileId)
                if newroot.count == 0 {
                    activityIndicator.startAnimating()
                    
                    CloudFactory.shared[storageName]?.list(fileId: result[indexPath.row].id ?? "") {
                        DispatchQueue.main.async {
                            self.activityIndicator.stopAnimating()
                            self.navigationController?.pushViewController(next, animated: true)
                        }
                    }
                }
                else {
                    self.navigationController?.pushViewController(next, animated: true)
                }
            }
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        activityIndicator.center = tableView.center
        activityIndicator.center.y = tableView.bounds.size.height/2 + tableView.contentOffset.y
    }
    
    @objc func cancelButtonDidTap(_ sender: UIBarButtonItem)
    {
        onCancel()
    }

    @objc func doneButtonDidTap(_ sender: UIBarButtonItem)
    {
        onDone(storageName, rootFileId)
    }
}

public class ChildStorage: RemoteStorageBase {
    var baseRootStorage: String = ""
    var baseRootFileId: String = ""

    public init(name: String) {
        super.init()
        storageName = name
        baseRootStorage = getKeyChain(key: "\(name)_rootStorage") ?? ""
        baseRootFileId = getKeyChain(key: "\(name)_rootFileId") ?? ""
    }
    
    override public func cancel() {
        super.cancel()
        guard let s = CloudFactory.shared[baseRootStorage] as? RemoteStorageBase else {
            return
        }
        s.cancel()
    }
    
    override public func auth(onFinish: ((Bool) -> Void)?) -> Void {
        if baseRootFileId != "" && baseRootFileId != "" {
            onFinish?(true)
            return
        }
        DispatchQueue.main.async {
            let top = UIApplication.topViewController()!
            let root = ViewControllerRoot()
            root.storages = CloudFactory.shared.storages.filter { $0 != self.storageName}
            root.onCancel = {
                DispatchQueue.main.async {
                    top.navigationController?.popToViewController(top, animated: true)
                    onFinish?(false)
                }
            }
            root.onDone = { rootstrage, rootid in
                self.baseRootStorage = rootstrage
                self.baseRootFileId = rootid

                os_log("%{public}@", log: self.log, type: .info, "saveInfo")
                let _ = self.setKeyChain(key: "\(self.storageName!)_rootStorage", value: self.baseRootStorage)
                let _ = self.setKeyChain(key: "\(self.storageName!)_rootFileId", value: self.baseRootFileId)
                let _ = self.setKeyChain(key: "\(self.baseRootStorage)_depended_\(self.storageName!)", value: self.storageName!)

                guard let s = CloudFactory.shared[self.baseRootStorage] as? RemoteStorageBase else {
                    top.navigationController?.popToViewController(top, animated: true)
                    onFinish?(false)
                    return
                }
                let group = DispatchGroup()
                group.enter()
                DispatchQueue.global().async {
                    s.list(fileId: self.baseRootFileId) {
                        group.leave()
                    }
                }

                DispatchQueue.main.async {
                    top.navigationController?.popToViewController(top, animated: true)
                    group.notify(queue: .global()) {
                        onFinish?(true)
                    }
                }
            }
            top.navigationController?.pushViewController(root, animated: true)
        }
    }
    
    override public func logout() {
        if let name = storageName {
            let _ = delKeyChain(key: "\(name)_rootStorage")
            let _ = delKeyChain(key: "\(name)_rootFileId")
        }
        super.logout()
    }
    
    func ConvertDecryptName(name: String) -> String {
        return name
    }
    
    func ConvertDecryptSize(size: Int64) -> Int64 {
        return size
    }

    func ConvertEncryptName(name: String, folder: Bool) -> String {
        return name
    }
    
    func ConvertEncryptSize(size: Int64) -> Int64 {
        return size
    }
    

    override func ListChildren(fileId: String, path: String, onFinish: (() -> Void)?) {
        let fixFileId = (fileId == "") ? "\(baseRootStorage)\n\(baseRootFileId)" : fileId
        let array = fixFileId.components(separatedBy: .newlines)
        let baseStorage = array[0]
        let baseFileId = array[1]
        guard let s = CloudFactory.shared[baseStorage] as? RemoteStorageBase else {
            onFinish?()
            return
        }
        
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            s.list(fileId: baseFileId) {
                group.leave()
            }
        }

        group.notify(queue: .main) {
            let viewContext = CloudFactory.shared.data.persistentContainer.viewContext

            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "RemoteData")
            fetchRequest.predicate = NSPredicate(format: "parent == %@ && storage == %@", baseFileId, baseStorage)
            if let result = try? viewContext.fetch(fetchRequest), let items = result as? [RemoteData] {
                for item in items {
                    let newid = "\(item.storage!)\n\(item.id!)"
                    let newname = self.ConvertDecryptName(name: item.name!)
                    let newcdate = item.cdate
                    let newmdate = item.mdate
                    let newfolder = item.folder
                    let newsize = self.ConvertDecryptSize(size: item.size)
                    
                    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "RemoteData")
                    fetchRequest.predicate = NSPredicate(format: "id == %@ && storage == %@", newid, self.storageName ?? "")
                    if let result = try? viewContext.fetch(fetchRequest) {
                        for object in result {
                            viewContext.delete(object as! NSManagedObject)
                        }
                    }
                        
                    let newitem = RemoteData(context: viewContext)
                    newitem.storage = self.storageName
                    newitem.id = newid
                    newitem.name = newname
                    let comp = newname.components(separatedBy: ".")
                    if comp.count >= 1 {
                        newitem.ext = comp.last!
                    }
                    newitem.cdate = newcdate
                    newitem.mdate = newmdate
                    newitem.folder = newfolder
                    newitem.size = newsize
                    newitem.hashstr = ""
                    newitem.parent = fileId
                    if fileId == "" {
                        newitem.path = "\(self.storageName ?? ""):/\(newname)"
                    }
                    else {
                        newitem.path = "\(path)/\(newname)"
                    }
                }
                try? viewContext.save()
            }
            
            DispatchQueue.global().async {
                onFinish?()
            }
        }
    }

    public override func getRaw(fileId: String) -> RemoteItem? {
        return NetworkRemoteItem(storage: storageName ?? "", id: fileId)
    }
    
    public override func getRaw(path: String) -> RemoteItem? {
        return NetworkRemoteItem(path: path)
    }

    public override func makeFolder(parentId: String, parentPath: String, newname: String, callCount: Int = 0, onFinish: ((String?) -> Void)?) {

        let array = (parentId == "") ? [baseRootStorage, baseRootFileId] : parentId.components(separatedBy: .newlines)
        let baseStorage = array[0]
        let baseFileId = array[1]
        if baseStorage == "" {
            onFinish?(nil)
            return
        }
        guard let s = CloudFactory.shared[baseStorage] as? RemoteStorageBase else {
            onFinish?(nil)
            return
        }

        var newBaseId = ""
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            s.mkdir(parentId: baseFileId, newname: self.ConvertEncryptName(name: newname, folder: true)) { id in
                if let id = id {
                    newBaseId = id
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            let viewContext = CloudFactory.shared.data.persistentContainer.viewContext
            var ret: String?
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "RemoteData")
            fetchRequest.predicate = NSPredicate(format: "id == %@ && storage == %@", newBaseId, baseStorage)
            if let result = try? viewContext.fetch(fetchRequest), let items = result as? [RemoteData] {
                if let item = items.first {
                    let newid = "\(item.storage!)\n\(item.id!)"
                    let newname = self.ConvertDecryptName(name: item.name!)
                    let newcdate = item.cdate
                    let newmdate = item.mdate
                    let newfolder = item.folder
                    let newsize = self.ConvertDecryptSize(size: item.size)
                    
                    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "RemoteData")
                    fetchRequest.predicate = NSPredicate(format: "id == %@ && storage == %@", newid, self.storageName ?? "")
                    if let result = try? viewContext.fetch(fetchRequest) {
                        for object in result {
                            viewContext.delete(object as! NSManagedObject)
                        }
                    }
                    
                    let newitem = RemoteData(context: viewContext)
                    newitem.storage = self.storageName
                    newitem.id = newid
                    newitem.name = newname
                    let comp = newname.components(separatedBy: ".")
                    if comp.count >= 1 {
                        newitem.ext = comp.last!
                    }
                    newitem.cdate = newcdate
                    newitem.mdate = newmdate
                    newitem.folder = newfolder
                    newitem.size = newsize
                    newitem.hashstr = ""
                    newitem.parent = parentId
                    if parentId == "" {
                        newitem.path = "\(self.storageName ?? ""):/\(newname)"
                    }
                    else {
                        newitem.path = "\(parentPath)/\(newname)"
                    }
                    ret = newid
                    try? viewContext.save()
                }
            }
            
            DispatchQueue.global().async {
                onFinish?(ret)
            }
        }
    }
    
    override func deleteItem(fileId: String, callCount: Int = 0, onFinish: ((Bool) -> Void)?) {
        guard fileId != "" else {
            onFinish?(false)
            return
        }
        
        let array = fileId.components(separatedBy: .newlines)
        let baseStorage = array[0]
        let baseFileId = array[1]
        if baseFileId == "" || baseStorage == "" {
            onFinish?(false)
            return
        }
        guard let s = CloudFactory.shared[baseStorage] as? RemoteStorageBase else {
            onFinish?(false)
            return
        }
        
        var done = false
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            s.delete(fileId: baseFileId) { success in
                done = success
                group.leave()
            }
        }
        group.notify(queue: .main) {
            guard done else {
                DispatchQueue.global().async {
                    onFinish?(false)
                }
                return
            }
            let viewContext = CloudFactory.shared.data.persistentContainer.viewContext
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "RemoteData")
            fetchRequest.predicate = NSPredicate(format: "id == %@ && storage == %@", fileId, self.storageName!)
            if let result = try? viewContext.fetch(fetchRequest), let items = result as? [RemoteData] {
                for item in items {
                    viewContext.delete(item)
                }
                try? viewContext.save()
            }
            
            DispatchQueue.global().async {
                onFinish?(true)
            }
        }
    }

    override func renameItem(fileId: String, newname: String, callCount: Int = 0, onFinish: ((String?) -> Void)?) {
        guard fileId != "" else {
            onFinish?(nil)
            return
        }
        
        let array = fileId.components(separatedBy: .newlines)
        let baseStorage = array[0]
        let baseFileId = array[1]
        if baseFileId == "" || baseStorage == "" {
            onFinish?(nil)
            return
        }
        guard let b = CloudFactory.shared[baseStorage]?.get(fileId: baseFileId) else {
            onFinish?(nil)
            return
        }
        guard let c = CloudFactory.shared[storageName!]?.get(fileId: fileId) else {
            onFinish?(nil)
            return
        }
        
        let group = DispatchGroup()
        var parentPath = ""
        var parentId = c.parent
        if parentId != "" {
            group.enter()
            DispatchQueue.main.async {
                defer { group.leave() }
                
                let viewContext = CloudFactory.shared.data.persistentContainer.viewContext
                
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "RemoteData")
                fetchRequest.predicate = NSPredicate(format: "id == %@ && storage == %@", parentId, self.storageName ?? "")
                if let result = try? viewContext.fetch(fetchRequest) {
                    if let items = result as? [RemoteData] {
                        parentPath = items.first?.path ?? ""
                    }
                }
            }
        }
        var newBaseId = ""
        group.enter()
        DispatchQueue.global().async {
            b.rename(newname: self.ConvertEncryptName(name: newname, folder: b.isFolder)) { id in
                if let id = id {
                    newBaseId = id
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            let viewContext = CloudFactory.shared.data.persistentContainer.viewContext
            let fetchRequest1 = NSFetchRequest<NSFetchRequestResult>(entityName: "RemoteData")
            fetchRequest1.predicate = NSPredicate(format: "id == %@ && storage == %@", fileId, self.storageName!)
            if let result = try? viewContext.fetch(fetchRequest1), let items1 = result as? [RemoteData] {
                for item in items1 {
                    viewContext.delete(item)
                }
            }

            var ret: String?
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "RemoteData")
            fetchRequest.predicate = NSPredicate(format: "id == %@ && storage == %@", newBaseId, baseStorage)
            if let result = try? viewContext.fetch(fetchRequest), let items = result as? [RemoteData] {
                if let item = items.first {
                    let newid = "\(item.storage!)\n\(item.id!)"
                    let newname = self.ConvertDecryptName(name: item.name!)
                    let newcdate = item.cdate
                    let newmdate = item.mdate
                    let newfolder = item.folder
                    let newsize = self.ConvertDecryptSize(size: item.size)
                    
                    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "RemoteData")
                    fetchRequest.predicate = NSPredicate(format: "id == %@ && storage == %@", newid, self.storageName ?? "")
                    if let result = try? viewContext.fetch(fetchRequest) {
                        for object in result {
                            viewContext.delete(object as! NSManagedObject)
                        }
                    }
                    
                    let newitem = RemoteData(context: viewContext)
                    newitem.storage = self.storageName
                    newitem.id = newid
                    newitem.name = newname
                    let comp = newname.components(separatedBy: ".")
                    if comp.count >= 1 {
                        newitem.ext = comp.last!
                    }
                    newitem.cdate = newcdate
                    newitem.mdate = newmdate
                    newitem.folder = newfolder
                    newitem.size = newsize
                    newitem.hashstr = ""
                    newitem.parent = parentId
                    if parentId == "" {
                        newitem.path = "\(self.storageName ?? ""):/\(newname)"
                    }
                    else {
                        newitem.path = "\(parentPath)/\(newname)"
                    }
                    ret = newid
                }
            }
            try? viewContext.save()

            DispatchQueue.global().async {
                onFinish?(ret)
            }
        }
    }
    
    override func changeTime(fileId: String, newdate: Date, callCount: Int = 0, onFinish: ((String?) -> Void)?) {
        guard fileId != "" else {
            onFinish?(nil)
            return
        }
        
        let array = fileId.components(separatedBy: .newlines)
        let baseStorage = array[0]
        let baseFileId = array[1]
        if baseFileId == "" || baseStorage == "" {
            onFinish?(nil)
            return
        }
        guard let b = CloudFactory.shared[baseStorage]?.get(fileId: baseFileId) else {
            onFinish?(nil)
            return
        }
        guard let c = CloudFactory.shared[storageName!]?.get(fileId: fileId) else {
            onFinish?(nil)
            return
        }
        
        let group = DispatchGroup()
        var parentPath = ""
        var parentId = c.parent
        if parentId != "" {
            group.enter()
            DispatchQueue.main.async {
                defer { group.leave() }
                
                let viewContext = CloudFactory.shared.data.persistentContainer.viewContext
                
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "RemoteData")
                fetchRequest.predicate = NSPredicate(format: "id == %@ && storage == %@", parentId, self.storageName ?? "")
                if let result = try? viewContext.fetch(fetchRequest) {
                    if let items = result as? [RemoteData] {
                        parentPath = items.first?.path ?? ""
                    }
                }
            }
        }
        var newBaseId = ""
        group.enter()
        DispatchQueue.global().async {
            b.changetime(newdate: newdate) { id in
                if let id = id {
                    newBaseId = id
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            let viewContext = CloudFactory.shared.data.persistentContainer.viewContext
            let fetchRequest1 = NSFetchRequest<NSFetchRequestResult>(entityName: "RemoteData")
            fetchRequest1.predicate = NSPredicate(format: "id == %@ && storage == %@", fileId, self.storageName!)
            if let result = try? viewContext.fetch(fetchRequest1), let items1 = result as? [RemoteData] {
                for item in items1 {
                    viewContext.delete(item)
                }
            }
            
            var ret: String?
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "RemoteData")
            fetchRequest.predicate = NSPredicate(format: "id == %@ && storage == %@", newBaseId, baseStorage)
            if let result = try? viewContext.fetch(fetchRequest), let items = result as? [RemoteData] {
                if let item = items.first {
                    let newid = "\(item.storage!)\n\(item.id!)"
                    let newname = self.ConvertDecryptName(name: item.name!)
                    let newcdate = item.cdate
                    let newmdate = item.mdate
                    let newfolder = item.folder
                    let newsize = self.ConvertDecryptSize(size: item.size)
                    
                    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "RemoteData")
                    fetchRequest.predicate = NSPredicate(format: "id == %@ && storage == %@", newid, self.storageName ?? "")
                    if let result = try? viewContext.fetch(fetchRequest) {
                        for object in result {
                            viewContext.delete(object as! NSManagedObject)
                        }
                    }
                    
                    let newitem = RemoteData(context: viewContext)
                    newitem.storage = self.storageName
                    newitem.id = newid
                    newitem.name = newname
                    let comp = newname.components(separatedBy: ".")
                    if comp.count >= 1 {
                        newitem.ext = comp.last!
                    }
                    newitem.cdate = newcdate
                    newitem.mdate = newmdate
                    newitem.folder = newfolder
                    newitem.size = newsize
                    newitem.hashstr = ""
                    newitem.parent = parentId
                    if parentId == "" {
                        newitem.path = "\(self.storageName ?? ""):/\(newname)"
                    }
                    else {
                        newitem.path = "\(parentPath)/\(newname)"
                    }
                    ret = newid
                }
            }
            try? viewContext.save()
            
            DispatchQueue.global().async {
                onFinish?(ret)
            }
        }
    }
    
    override func moveItem(fileId: String, fromParentId: String, toParentId: String, callCount: Int = 0, onFinish: ((String?) -> Void)?) {

        guard fileId != "" else {
            onFinish?(nil)
            return
        }
        
        let array = fileId.components(separatedBy: .newlines)
        let baseStorage = array[0]
        let baseFileId = array[1]
        if baseFileId == "" || baseStorage == "" {
            onFinish?(nil)
            return
        }
        
        let array3 = (toParentId == "") ? [baseRootStorage, baseRootFileId] : toParentId.components(separatedBy: .newlines)
        let tobaseStorage = array3[0]
        let tobaseFileId = array3[1]
        if tobaseStorage == "" {
            onFinish?(nil)
            return
        }
        
        if baseStorage != tobaseStorage {
            onFinish?(nil)
            return
        }
        
        guard let b = CloudFactory.shared[baseStorage]?.get(fileId: baseFileId) else {
            onFinish?(nil)
            return
        }
        
        let group = DispatchGroup()
        var toParentPath = "\(tobaseStorage):/"
        if toParentId != "" {
            group.enter()
            DispatchQueue.main.async {
                defer { group.leave() }
                
                let viewContext = CloudFactory.shared.data.persistentContainer.viewContext
                
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "RemoteData")
                fetchRequest.predicate = NSPredicate(format: "id == %@ && storage == %@", toParentId, self.storageName ?? "")
                if let result = try? viewContext.fetch(fetchRequest) {
                    if let items = result as? [RemoteData] {
                        toParentPath = items.first?.path ?? ""
                    }
                }
            }
        }

        var newBaseId = ""
        group.enter()
        DispatchQueue.global().async {
            b.move(toParentId: tobaseFileId) { id in
                if let id = id {
                    newBaseId = id
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            let viewContext = CloudFactory.shared.data.persistentContainer.viewContext
            let fetchRequest1 = NSFetchRequest<NSFetchRequestResult>(entityName: "RemoteData")
            fetchRequest1.predicate = NSPredicate(format: "id == %@ && storage == %@", fileId, self.storageName!)
            if let result = try? viewContext.fetch(fetchRequest1), let items1 = result as? [RemoteData] {
                for item in items1 {
                    viewContext.delete(item)
                }
            }
            
            var ret: String?
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "RemoteData")
            fetchRequest.predicate = NSPredicate(format: "id == %@ && storage == %@", newBaseId, baseStorage)
            if let result = try? viewContext.fetch(fetchRequest), let items = result as? [RemoteData] {
                if let item = items.first {
                    let newid = "\(item.storage!)\n\(item.id!)"
                    let newname = self.ConvertDecryptName(name: item.name!)
                    let newcdate = item.cdate
                    let newmdate = item.mdate
                    let newfolder = item.folder
                    let newsize = self.ConvertDecryptSize(size: item.size)
                    
                    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "RemoteData")
                    fetchRequest.predicate = NSPredicate(format: "id == %@ && storage == %@", newid, self.storageName ?? "")
                    if let result = try? viewContext.fetch(fetchRequest) {
                        for object in result {
                            viewContext.delete(object as! NSManagedObject)
                        }
                    }
                    
                    let newitem = RemoteData(context: viewContext)
                    newitem.storage = self.storageName
                    newitem.id = newid
                    newitem.name = newname
                    let comp = newname.components(separatedBy: ".")
                    if comp.count >= 1 {
                        newitem.ext = comp.last!
                    }
                    newitem.cdate = newcdate
                    newitem.mdate = newmdate
                    newitem.folder = newfolder
                    newitem.size = newsize
                    newitem.hashstr = ""
                    newitem.parent = toParentId
                    if toParentId == "" {
                        newitem.path = "\(self.storageName ?? ""):/\(newname)"
                    }
                    else {
                        newitem.path = "\(toParentPath)/\(newname)"
                    }
                    ret = newid
                }
            }
            try? viewContext.save()
            
            DispatchQueue.global().async {
                onFinish?(ret)
            }
        }
    }
    
    override func uploadFile(parentId: String, uploadname: String, target: URL, onFinish: ((String?)->Void)?) {
        os_log("%{public}@", log: log, type: .debug, "uploadFile(\(String(describing: type(of: self))):\(storageName ?? "") \(uploadname)->\(parentId) \(target)")
        
        let array = (parentId == "") ? [baseRootStorage, baseRootFileId] : parentId.components(separatedBy: .newlines)
        let baseStorage = array[0]
        let baseFileId = array[1]
        if baseStorage == "" {
            try? FileManager.default.removeItem(at: target)
            onFinish?(nil)
            return
        }
        
        guard let s = CloudFactory.shared[baseStorage] as? RemoteStorageBase else {
            try? FileManager.default.removeItem(at: target)
            onFinish?(nil)
            return
        }
        guard let b = CloudFactory.shared[baseStorage]?.get(fileId: baseFileId) else {
            try? FileManager.default.removeItem(at: target)
            onFinish?(nil)
            return
        }
        let parentPath = b.path
        
        DispatchQueue.global().async {
            if let crypttarget = self.processFile(target: target) {
                s.upload(parentId: baseFileId, uploadname: self.ConvertEncryptName(name: uploadname, folder: false), target: crypttarget) { newBaseId in
                    guard let newBaseId = newBaseId else {
                        try? FileManager.default.removeItem(at: target)
                        onFinish?(nil)
                        return
                    }
                    
                    DispatchQueue.main.async {
                        var ret: String? = nil
                        let viewContext = CloudFactory.shared.data.persistentContainer.viewContext
                        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "RemoteData")
                        fetchRequest.predicate = NSPredicate(format: "id == %@ && storage == %@", newBaseId, baseStorage)
                        if let result = try? viewContext.fetch(fetchRequest), let items = result as? [RemoteData] {
                            if let item = items.first {
                                let newid = "\(item.storage!)\n\(item.id!)"
                                let newname = self.ConvertDecryptName(name: item.name!)
                                let newcdate = item.cdate
                                let newmdate = item.mdate
                                let newfolder = item.folder
                                let newsize = self.ConvertDecryptSize(size: item.size)
                                
                                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "RemoteData")
                                fetchRequest.predicate = NSPredicate(format: "id == %@ && storage == %@", newid, self.storageName ?? "")
                                if let result = try? viewContext.fetch(fetchRequest) {
                                    for object in result {
                                        viewContext.delete(object as! NSManagedObject)
                                    }
                                }
                                
                                let newitem = RemoteData(context: viewContext)
                                newitem.storage = self.storageName
                                newitem.id = newid
                                newitem.name = newname
                                let comp = newname.components(separatedBy: ".")
                                if comp.count >= 1 {
                                    newitem.ext = comp.last!
                                }
                                newitem.cdate = newcdate
                                newitem.mdate = newmdate
                                newitem.folder = newfolder
                                newitem.size = newsize
                                newitem.hashstr = ""
                                newitem.parent = parentId
                                if parentId == "" {
                                    newitem.path = "\(self.storageName ?? ""):/\(newname)"
                                }
                                else {
                                    newitem.path = "\(parentPath)/\(newname)"
                                }
                                ret = newid
                            }
                        }
                        try? viewContext.save()
                        
                        DispatchQueue.global().async {
                            onFinish?(ret)
                        }
                    }
                }
            }
            try? FileManager.default.removeItem(at: target)
        }
    }
    
    func processFile(target: URL) -> URL? {
        return target
    }
    
    override func readFile(fileId: String, start: Int64?, length: Int64?, callCount: Int = 0, onFinish: ((Data?) -> Void)?) {
        let array = fileId.components(separatedBy: .newlines)
        let baseStorage = array[0]
        let baseFileId = array[1]
        if baseFileId == "" || baseStorage == "" {
            onFinish?(nil)
            return
        }
        guard let s = CloudFactory.shared[baseStorage] else {
            onFinish?(nil)
            return
        }
        DispatchQueue.global().async {
            s.read(fileId: baseFileId, start: start, length: length, onFinish: onFinish)
        }
    }
}
