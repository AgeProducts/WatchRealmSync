//
//  SupportLibs.swift
//  WatchRealmSync
//
//  Created by Takuji Hori on 2017/02/14.
//  Copyright © 2017 AgePro. All rights reserved.
//

import UIKit

class Crypto {

    static  func MD5(input:Any) -> String {
        let className = String(describing: type(of: input))
        var data = Data()
        if className == "Int" {
            data = String(format: "%x", input as! Int).description.data(using: .utf8)!
        } else {
            data = (input as AnyObject).description.data(using: .utf8)!
        }
        let length = Int(CC_MD5_DIGEST_LENGTH)
        var digest = [UInt8](repeating: 0, count: length)
        _ = data.withUnsafeBytes { CC_MD5($0, CC_LONG(data.count), &digest) }
        let cryptDigest = digest.map { String(format: "%02x", $0) }.joined(separator: "")
        return cryptDigest
    }
}

class DateHelper {
    
    static func onceUponATime() -> Date {
        var  calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date1970_01_01_00_00_00_00 =
            calendar.date(from: DateComponents(year: 1970, month: 01, day: 01,
                                               hour: 00, minute: 00, second: 00, nanosecond: 0))!
        return date1970_01_01_00_00_00_00
    }
    
    static func farDistantFuture() -> Date {               // In iOS, Year2038 problem is not matter!
        var  calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date2030_01_19_03_14_07_00 =
            calendar.date(from: DateComponents(year: 2038, month: 01, day: 19,
                                               hour: 03, minute: 14, second: 07, nanosecond: 00))!
        return date2030_01_19_03_14_07_00
    }
    
    static func makeDateFormatter( _ dateFormatter: inout DateFormatter) {
        let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        dateFormatter.calendar = calendar
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
    }
    
    static func firstDateFromYearMonthDay(_ year:Int, month:Int, day:Int) -> Date {
        let  calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        let resuleDate =
            calendar.date(from: DateComponents(year: year, month: month, day: day,
                                               hour: 00, minute: 00, second: 00, nanosecond: 00))!
        return resuleDate
    }
    
    static func firstDateFromYear(_ year:Int) -> Date {
        return  firstDateFromYearMonthDay(year, month: 01, day: 01)
    }
    
    static func lastDateFromYearMonthDay(_ year:Int, month:Int, day:Int) -> Date {
        let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        let resuleDate =
            calendar.date(from: DateComponents(year: year, month: month, day: day,
                                               hour: 23, minute: 59, second: 59, nanosecond: 00))
        // hour: 23, minute: 59, second: 59, nanosecond: 1_000_000_000 - 1))
        return resuleDate!
    }
    
    static func lastDateFromYear(_ year:Int) -> Date {
        let lastDay = dateCountFromYearMonth(year, month: 12)
        return  lastDateFromYearMonthDay(year, month: 12, day: lastDay)
    }
    
    static func dateCountFromYearMonth(_ year:Int, month:Int) -> Int {
        var tmpFormatter = DateFormatter()
        makeDateFormatter(&tmpFormatter)
        tmpFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss";
        let tmpDate = tmpFormatter.date(from: String(format: "%4d-%2d-01 00:00:00", year, month))
        let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        let range = (calendar as NSCalendar?)?.range(of: .day, in: .month, for:tmpDate!)
        return range!.length
    }
    
    static func firstDateFromDate(_ date:Date) -> Date {
        let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        var dateComponents = (calendar as Calendar).dateComponents([.day, .month, .year], from: date)
        dateComponents.hour = 00
        dateComponents.minute = 00
        dateComponents.second = 00
        return  calendar.date(from: dateComponents)!
    }
    
    static func lastDateFromDate(_ date:Date) -> Date {
        let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        var dateComponents = (calendar as Calendar).dateComponents([.day, .month, .year], from: date)
        dateComponents.hour = 23
        dateComponents.minute = 59
        dateComponents.second = 59
        // dateComponents.nanosecond = 1_000_000_000 - 1
        return  calendar.date(from: dateComponents)!
    }
    
    static func yearMonthDayFromDate(_ date:Date) -> (Int, Int, Int) {
        let calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        let dateComponents = (calendar as Calendar).dateComponents([.day, .month, .year], from: date)
        return (dateComponents.year!, dateComponents.month!, dateComponents.day!)
    }
    
    static func getDateBeforeOrAfterSomeDay(baseDate:Date, day:Double) -> Date {
        var resultDate:Date
        if day > 0 {
            resultDate = Date(timeInterval: (60*60*24)*day, since: baseDate as Date)
        } else {
            resultDate = Date(timeInterval: -(60*60*24)*fabs(day), since: baseDate as Date)
        }
        return resultDate
    }
    
    static func getDateBeforeOrAfterSomeWeek(baseDate:Date, week:Double) -> Date {
        return getDateBeforeOrAfterSomeDay(baseDate: baseDate, day: week*7)
    }
    
    static func getDateBeforeOrAfterSomeMonth(baseDate:Date, month:Double) -> Date {
        return getDateBeforeOrAfterSomeDay(baseDate: baseDate, day: month*31)
    }
}

public class FileHelper {
    
    // tmp/
    static func temporaryDirectory() -> String {
        return NSTemporaryDirectory()
    }
    
    // tmp/fileName
    static func temporaryDirectoryWithFileName(fileName: String) -> String {
        return temporaryDirectory().stringByAppendingPathComponent(path: fileName)
    }
    
    // Documents/
    static func documentDirectory() -> String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    }
    
    // Documents/fileName
    static func documentDirectoryWithFileName(fileName: String) -> String {
        return documentDirectory().stringByAppendingPathComponent(path: fileName)
    }
    
    static func fileExists(path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    static func removeFilePath(path: String) -> Bool {
        do {
            try FileManager.default.removeItem(atPath: path)
            return true
        } catch let error as NSError {
            NSLog ("File remove error: \(error.localizedDescription) \(path)")
            return false
        }
    }
    
    static func fileSizePath(path: String) -> Int {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path) as NSDictionary
            return Int(attributes.fileSize())
        }
        catch let error as NSError {
            NSLog ("File size error: \(error.localizedDescription) \(path)")
            return 0
        }
    }
    
    static func readFileWithData(path: String) -> Data! {
        if fileExists(path: path) == false {
            return nil
        }
        guard let fileHandle = FileHandle(forReadingAtPath: path) else {
            return nil
        }
        
        let data = fileHandle.readDataToEndOfFile()
        fileHandle.closeFile()
        return data
    }
    
    static func readFileWithImage(path: String) -> UIImage! {
        guard let data = readFileWithData(path: path) else {
            print("File read error")
            return nil
        }
        guard let imageData = UIImage.init(data: data, scale: 1.0) else {
            print("UIImage convert error")
            return nil
        }
        return imageData
    }
    
    static func writeFileWithData(path: String, data: Data) -> Bool {
        if FileManager.default.createFile(atPath: path, contents: data, attributes: nil) == true {
            // print ("File successful creation: \(path)")
            return true
        } else {
            print ("File already exist: \(path)")
            return false
        }
    }
    
    static func directorContents(atPath: String) -> [String] {
        var contents: [String] = []
        var isDir: ObjCBool = true
        if FileManager.default.fileExists(atPath: atPath, isDirectory: &isDir) {
            do {
                contents = try FileManager.default.contentsOfDirectory(atPath: atPath)
            } catch let error as NSError {
                print(error.localizedDescription)
            }
        }
        return contents
    }
    
    static func isElapsedFileModificationDate(path: String, elapsedTime: TimeInterval) throws -> Bool {
        if !fileExists(path: path) {
            return false
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: path) as NSDictionary
        guard let date = attributes.fileModificationDate() else {
            return false
        }
        return elapsedTime < NSDate().timeIntervalSince(date)
    }
}


class RandomMaker {
    
    static func randomFloat(Min _Min : Float, Max _Max : Float)->Float {
        return (Float(arc4random_uniform(UINT32_MAX)) / Float(UINT32_MAX) ) * (_Max - _Min) + _Min
    }
    
    static func randomDouble(Min _Min : Double, Max _Max : Double)->Double {
        return (Double(arc4random_uniform(UINT32_MAX)) / Double(UINT32_MAX) ) * (_Max - _Min) + _Min
    }
    
    static func randomNumIntegerWithLimits(lower:Int, upper:Int) -> Int {
        if upper < lower {
            return -1
        }
        return Int(arc4random_uniform(UInt32(upper) - UInt32(lower)) + UInt32(lower))
    }
    
    static func randomStringWithLength(_ len:Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var result:String = ""
        if len <= 0 {
            NSLog ("randomStringWithLength: error length 0 error");
            return ""
        }
        for _ in 0..<len {
            let startindex = letters.characters.index(letters.startIndex, offsetBy: Int(arc4random_uniform(UInt32(letters.characters.count))))
            let endindex = letters.index(startindex, offsetBy: 1)
            result += letters.substring(with: startindex..<endindex)
        }
        return result
    }
    
    static func randomNihonngoStringWithLength(_ len:Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789雨にもまけず風にもまけず雪にも夏の暑さにもまけぬ丈夫なからだをもち欲はなく決して怒らずいつもしずかにわらっている一日に玄米四合と味噌と少しの野菜をたべあらゆることをじぶんをかんじょうに入れずによくみききしわかりそしてわすれず野原の松の林の蔭の小さな萓ぶきの小屋にいて東に病気のこどもあれば行って看病してやり西につかれた母あれば行ってその稲の束を負い南に死にそうな人あれば行ってこわがらなくてもいいといい北にけんかやそしょうがあればつまらないからやめろといいひでりのときはなみだをながしさむさのなつはオロオロあるきみんなにデクノボーとよばれほめられもせずくにもされずそういうものにわたしはなりたい"
        var result:String = ""
        if len <= 0 {
            NSLog ("randomStringWithLength: error length 0 error");
            return ""
        }
        for _ in 0..<len {
            let startindex = letters.characters.index(letters.startIndex, offsetBy: Int(arc4random_uniform(UInt32(letters.characters.count))))
            let endindex = letters.index(startindex, offsetBy: 1)
            result += letters.substring(with: startindex..<endindex)
        }
        return result
    }
    
    static func randomDate3(_ firstDate:Date?, lastDate:Date?) -> Date? {
        let interval = (lastDate?.timeIntervalSince(firstDate!))!
        return  firstDate?.addingTimeInterval(randomDouble(Min : 0, Max : interval))
    }
    
    static func randomBool(percent:Double) -> Bool {
        let result = randomDouble(Min : 0, Max : 100.0)
        if result < percent {
            return true
        } else {
            return false
        }
    }
}

extension String {
    func stringByAppendingPathComponent(path: String) -> String {
        let nsSt = self as NSString
        return nsSt.appendingPathComponent(path)
    }
}

extension UIColor {
    
    class func rgbColor(_ rgbValue: UInt) -> UIColor{
        return UIColor(
            red:   CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >>  8) / 255.0,
            blue:  CGFloat( rgbValue & 0x0000FF)        / 255.0,
            alpha: CGFloat(1.0)
        )
    }
}

let yearformatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yy/M/dd HH:mm"
    // f.dateFormat = "yy/MM/dd"
    // f.dateStyle = .none
    // f.timeStyle = .short
    return f
}()

let dateformatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "M/dd HH:mm:ss"
    // f.dateFormat = "yy/MM/dd"
    // f.dateStyle = .none
    // f.timeStyle = .short
    return f
}()

let timeformatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "M/dd HH:mm:ss"
    // f.dateFormat = "HH:mm:ss"
    // f.dateStyle = .none
    // f.timeStyle = .short
    return f
}()

func dispatch_async_main(_ block: @escaping () -> ()) {
    DispatchQueue.main.async(execute: block)
}

func dispatch_async_global(_ block: @escaping () -> ()) {
    DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async(execute: block)
}

