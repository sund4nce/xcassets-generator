#!/usr/bin/swift

//.xcassets Generator 

import Foundation
‚
//let args = ["", "directory", "images.xcassets"]

let args = Process.arguments
let fileManager = NSFileManager()

var inputDirectory: String?
var outputAssetDirectory: String?

//Helper methods
func isDirectory(path: String) -> Bool {
    var isDir: ObjCBool = false
    if fileManager.fileExistsAtPath(path, isDirectory: &isDir) {
        return Bool(isDir)
    }
    return false
}

func checkArgs(args: [String]) -> Bool {
    if args.count == 3 {
        if isDirectory(args[1]) && args[2].hasSuffix(".xcassets") {
            inputDirectory = args[1]
            outputAssetDirectory = args[2]
            return true
        }
    }
    return false
}

func createDir(path: String) {
    do {
        try fileManager.createDirectoryAtPath(path, withIntermediateDirectories: false, attributes: nil)
    } catch _ as NSError { }
}

func copyFile(from: String, to: String) {
    do {
        try fileManager.copyItemAtPath(from, toPath: to)
    }
    catch _ as NSError { }
}

func infoJson() -> NSData {
    let json = [
        "info": [
            "version": 1,
            "author": "mort3m"
        ]
    ]
    return try! NSJSONSerialization.dataWithJSONObject(json, options: .PrettyPrinted)
}

func generateJSON(dir: String) -> NSData? {
    do {
        let files = try fileManager.contentsOfDirectoryAtPath(dir)
        var json = [String : AnyObject]()
        var imagesJson = [AnyObject]()
        
        for file in files {
            if file.hasSuffix(".png") {
                let name = (file as NSString).lastPathComponent
                
                //get scale - crap.
                var scale = "1x"
                if let scaleAt = file.rangeOfString("@") {
                    var scaleRange = scaleAt
                    scaleRange.endIndex = scaleRange.endIndex.advancedBy(2)
                    scaleRange.startIndex = scaleRange.startIndex.advancedBy(1)
                    scale = file.substringWithRange(scaleRange)
                }
                
                let imageJson: [String: AnyObject] = [
                    "idiom": "universal",
                    "scale": scale,
                    "filename": name
                ]
                imagesJson.append(imageJson)
            }
        }
        
        json["images"] = imagesJson
        json["info"] = [
            "version" : 1,
            "author" : "mort3m"
        ]
        
        return try NSJSONSerialization.dataWithJSONObject(json, options: .PrettyPrinted)
        
    } catch _ as NSError { }
    
    return nil
}

//Entry Point
if checkArgs(args) {
    
    //\u{001B}[0;36m
    print("")
    print("\u{001B}[0;36m [info] \u{001B}[0;37m started.")
    
    //Create xcassets folder
    createDir(outputAssetDirectory!)
    do {
        try infoJson().writeToFile("\(outputAssetDirectory!)/Contents.json", options: .AtomicWrite)
    } catch { }
    
    var enumerator: NSDirectoryEnumerator = fileManager.enumeratorAtPath(inputDirectory!)!
    var images = [String:[(old: String, new: String)]]()
    
    //Create subfolders
    while let element = enumerator.nextObject() as? String {
        if element.hasSuffix(".png") { // checks the extension
            
            var filename = (element as NSString).lastPathComponent
            var imageset = filename
            imageset = imageset.stringByReplacingOccurrencesOfString(".png", withString: "")
            imageset = imageset.characters.split{$0 == "@"}.map(String.init)[0]
            imageset += ".imageset"
            
            var filePath = (element as NSString).stringByDeletingLastPathComponent
            
            if images[filename] == nil {
                images[filename] = [(old: element, new: "\(filePath)/\(imageset)/\(filename)")]
                createDir("\(outputAssetDirectory!)/\(filePath)/\(imageset)")
            } else {
                images[filename]!.append((old: element, new: "\(filePath)/\(imageset)/\(filename)"))
            }
        } else if isDirectory("\(inputDirectory!)/\(element)") {
            createDir("\(outputAssetDirectory!)/\(element)")
        }
    }
    
    //copy images
    for imageName in images.keys {
        for imagePath in images[imageName]! {
            let output = "\(outputAssetDirectory!)/\(imagePath.new)"
            let input = "\(inputDirectory!)/\(imagePath.old)"
            copyFile(input, to: output)
        }
    }
    
    //Generate JSON per Folder
    enumerator = fileManager.enumeratorAtPath(outputAssetDirectory!)!
    while let element = enumerator.nextObject() as? String {
        if element.hasSuffix(".imageset") {
            do {
                if let json = generateJSON("\(outputAssetDirectory!)/\(element)") {
                    try json.writeToFile("\(outputAssetDirectory!)/\(element)/Contents.json", options: .AtomicWrite)
                }
            } catch { }
        } else {
            do {
                try infoJson().writeToFile("\(outputAssetDirectory!)/\(element)/Contents.json", options: .AtomicWrite)
            } catch { }
            
        }
    }
    
    print("\u{001B}[0;32m [done] \u{001B}[0;37m moved \(images.count) images.")
    print("")
    
} else {
    print("\u{001B}[0;31m [error] \u{001B}[0;37m Usage: ./generator.swift \"dir\" \".xcasset file\"")
}

