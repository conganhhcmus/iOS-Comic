//
//  Comic.swift
//  ComicApp
//
//  Created by KiD on 12/11/19.
//  Copyright © 2019 Le Van Anh. All rights reserved.
//

import Foundation
import UIKit
import Firebase
import RealmSwift

class Comic {
    static var id : String?
    static var isDownloaded : Bool = false
    static var chap : Int?
    static var nchap : Int?
}
class Shelf{
    static var listDownload: [DComic] = []
    static var listHistory: [DComic] = []
    static var listLike: [DComic] = []
    static func DownloadList(){
        if UserLocal.UserID != nil{
            let db = Firestore.firestore()
            let ref = db.collection("Users").document(UserLocal.UserID!)
            ref.updateData(["comicHistory": FieldValue.arrayUnion([])])
            ref.updateData(["comicLike": FieldValue.arrayUnion([])])
            ref.getDocument { (document, error) in
                if error == nil{
                    let listString = document?.data()?["comicHistory"] as? Array<String>
                    for idComic in listString!{
                        let comic = DComic()
                        comic.idComic = idComic
                        comic.totalSize = 1
                        comic.Dsize = 0
                        comic.finish = true
                        let db = Firestore.firestore()
                        let storage = Storage.storage()
                        let ref = db.collection("Comic").document(idComic)
                        ref.getDocument { (document, error) in
                            if error != nil{
                                return
                            } else{
                                if let document = document, document.exists {
                                    let data = document.data()
                                    comic.name = data?["name"] as? String
                                    comic.totalChap = data?["totalChap"] as? Int
                                    let posterPath = data?["posterPath"] as? String
                                    let storageRef = storage.reference().child(posterPath!)
                                    storageRef.getData(maxSize: 1 * 1024 * 1024) { data, error in
                                        if error == nil {
                                            comic.poster = data!
                                            listHistory.append(comic)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    let listString2 = document?.data()?["comicLike"] as? Array<String>
                    for idComic in listString2!{
                        let comic = DComic()
                        comic.idComic = idComic
                        comic.totalSize = 1
                        comic.Dsize = 0
                        comic.finish = true
                        let db = Firestore.firestore()
                        let storage = Storage.storage()
                        let ref = db.collection("Comic").document(idComic)
                        ref.getDocument { (document, error) in
                            if error != nil{
                                return
                            } else{
                                if let document = document, document.exists {
                                    let data = document.data()
                                    comic.name = data?["name"] as? String
                                    comic.totalChap = data?["totalChap"] as? Int
                                    let posterPath = data?["posterPath"] as? String
                                    let storageRef = storage.reference().child(posterPath!)
                                    storageRef.getData(maxSize: 1 * 1024 * 1024) { data, error in
                                        if error == nil {
                                            comic.poster = data!
                                            listLike.append(comic)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    static func DownloadCommic(_ comicID: String){
        let comic = DComic()
        comic.idComic = comicID
        comic.totalSize = 1
        comic.Dsize = 0
        let db = Firestore.firestore()
        let storage = Storage.storage()
        let ref = db.collection("Comic").document(comicID)
        ref.getDocument { (document, error) in
            if error != nil{
                return
            } else{
                if let document = document, document.exists {
                    let data = document.data()
                    comic.name = data?["name"] as? String
                    comic.totalChap = data?["totalChap"] as? Int
                    let posterPath = data?["posterPath"] as? String
                    let filePath = data?["filePath"] as? String
                    let storageRef = storage.reference().child(posterPath!)
                    // Download in memory with a maximum allowed size of 1MB (1 * 1024 * 1024 bytes)
                    storageRef.getData(maxSize: 1 * 1024 * 1024) { data, error in
                        if error == nil {
                            comic.poster = data!
                            listDownload.append(comic)
                            let realm = try! Realm()
                            if realm.objects(LComic.self).first != nil  {
                            } else{
                                try! realm.write {
                                    realm.add(LComic(value: ["comicID": comic.idComic ?? "","comicName": comic.name ?? "","comicNChap":comic.totalChap ?? 0,"comicPoster":comic.poster ?? Data()]))
                                }
                            }
                            var arrayCalcPercent = [[Int64]]()
                            for index in  0..<comic.totalChap!{
                                let tmpIndex = index
                                let list = List<Data>()
                                var path = ""
                                if index < 9 {
                                    path = "/00\(index + 1)"
                                } else if index < 99 {
                                    path = "/0\(index + 1)"
                                } else {
                                    path = "/\(index + 1)"
                                }
                                let storageRef = storage.reference().child(filePath! + path)
                                storageRef.listAll { (result, err) in
                                    if err != nil {
                                        print("Err")
                                        return
                                    } else {
                                        var tmp = result.items.count
                                        var tmp2 = 0
                                        arrayCalcPercent.append(Array(repeating: 0, count: 2*tmp))
                                        for item in result.items {
                                            let tmp1 = tmp2
                                            tmp2 += 1
                                            let task = item.getData(maxSize: 1 * 1024 * 1024) { data, error in
                                                if error != nil {
                                                    // Uh-oh, an error occurred!
                                                    return
                                                } else {
                                                    list.append(data!)
                                                    tmp -= 1
                                                    if tmp == 0{
                                                        if let comicl = realm.objects(LComic.self).filter("comicID == %@",comicID).first {
                                                            try! realm.write {
                                                                let chapterTmp = LChap()
                                                                chapterTmp.listImg = list
                                                                comicl.listChap.append(chapterTmp)
                                                            }
                                                            if comicl.listChap.count == comic.totalChap {
                                                                comic.finish = true
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            task.observe(.progress) { (snapshot) in
                                                let sizeOfImg = snapshot.progress!.completedUnitCount
                                                comic.Dsize = comic.Dsize! - arrayCalcPercent[tmpIndex][tmp1] + sizeOfImg
                                                arrayCalcPercent[tmpIndex][tmp1] = sizeOfImg
                                                if arrayCalcPercent[tmpIndex][arrayCalcPercent[tmpIndex].count / 2 + tmp1] != 1{
                                                    arrayCalcPercent[tmpIndex][arrayCalcPercent[tmpIndex].count / 2 + tmp1] = 1
                                                    comic.totalSize = comic.totalSize! + snapshot.progress!.totalUnitCount
                                                }
                                            }
                                        }
                                    }
                                }
                            }                            
                        }
                    }
                }
            }
        }
    }
    static func ComicRealmToRam(){
        let realm = try! Realm()
        let comics = realm.objects(LComic.self)
        for comic in comics{
            let rComic = DComic()
            rComic.name = comic.comicName
            rComic.idComic = comic.comicID
            rComic.finish = true
            rComic.poster = comic.comicPoster
            rComic.totalChap = comic.comicNChap
            listDownload.append(rComic)
        }
    }
}
class DComic: NSObject{
    var name: String? = ""
    var idComic: String? = ""
    var poster: Data? = nil
    var totalChap: Int? = 0
    var totalSize: Int64? = 1
    var Dsize: Int64? = 0
    var finish: Bool = false
}
