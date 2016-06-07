//
//  Sensors.swift
//  RLog
//
//  Created by Dr. Morg on 07.06.16.
//  Copyright © 2016 Alexey Rogov. All rights reserved.
//

import Foundation
import CoreBluetooth

let deviceName = "RLogCtrl"
// Service UUIDs
let UARTServiceUUID = CBUUID(string: "0000ffe0-0000-1000-8000-00805f9b34fb")
// Characteristic UUIDs
let RXTXCharUUID = CBUUID(string: "0000ffe1-0000-1000-8000-00805f9b34fb")


class Sensors {
    
    // Check name of device from advertisement data
    class func sensorsFound (advertisementData: [NSObject : AnyObject]!) -> Bool {
        let nameOfDeviceFound = (advertisementData as NSDictionary).objectForKey(CBAdvertisementDataLocalNameKey) as? NSString
        return (nameOfDeviceFound == deviceName)
    }
    
    // Check if the service has a valid UUID
    class func validService (service : CBService) -> Bool {
        if service.UUID == UARTServiceUUID {
            return true
        }
        else {
            return false
        }
    }
    
    // Check if the characteristic has a valid data UUID
    class func validDataCharacteristic (characteristic : CBCharacteristic) -> Bool {
        if characteristic.UUID == RXTXCharUUID {
            return true
        }
        else {
            return false
        }
    }
    
    // Get labels of all sensors
    class func getSensorLabels () -> [String] {
        let sensorLabels : [String] = [
            "BLE ET",
            "BLE BT"
        ]
        return sensorLabels
    }
    
    // Process the values from sensor
    // Convert NSData to Strings
    // Parsing string from Arduino
    class func getETBT(value : NSData) -> [String] {
        var dataFromSensor = String(data: value, encoding: NSUTF8StringEncoding)!
        dataFromSensor = dataFromSensor.stringByReplacingOccurrencesOfString("\r\n", withString: "")
        let array = dataFromSensor.componentsSeparatedByString(",")
        return array
    }
}
