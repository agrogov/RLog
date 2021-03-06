//
//  ViewController.swift
//  RLog
//
//  Created by Dr. Morg on 06.06.16.
//  Copyright © 2016 Alexey Rogov. All rights reserved.
//

import UIKit
import CoreBluetooth
import Charts

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var sensorsTableView: UITableView!
    @IBOutlet weak var lineChartView: LineChartView!
    
    //Bottom bar buttons
    @IBOutlet weak var btnStartLog: UIBarButtonItem!
    @IBOutlet weak var btnCharge: UIBarButtonItem!
    @IBOutlet weak var btnFCStart: UIBarButtonItem!
    @IBOutlet weak var btnFCStop: UIBarButtonItem!
    @IBOutlet weak var btnDrop: UIBarButtonItem!
    
    var xAxe = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18]
    var ChartValues = [0.0]
    var logStarted : Bool = false
    
    // BLE
    var centralManager : CBCentralManager!
    var sensorsPeripheral : CBPeripheral!
    var RXTXCharacteristic : CBCharacteristic?
    
    // Sensor Values
    var sensorsRequestTime : Double = 3
    var allSensorLabels : [String] = []
    var allSensorValues : [Double] = []
    var ET : Double!
    var BT : Double!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // Initialize central manager on load
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        // Set up table view
        setupSensorsTableView()
        
        // Initialize all sensor values and labels
        allSensorLabels = Sensors.getSensorLabels()
        for i in 0..<self.allSensorLabels.count {
            self.allSensorValues.append(Double(i*0))
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func sensorUpdate(){
        if Sensors.validDataCharacteristic(self.RXTXCharacteristic!) {
            // Read data from Sensor
            let stringData = ("READ\r\n" as NSString).dataUsingEncoding(NSUTF8StringEncoding)
            self.sensorsPeripheral.writeValue(stringData!, forCharacteristic: self.RXTXCharacteristic!, type: CBCharacteristicWriteType.WithResponse)
        }
    }
    
    func chartUpdate(){
        self.ChartValues.append(self.BT)
        setChart(xAxe, values: self.ChartValues)
    }
    
    func setChart(dataPoints: [Int], values: [Double]) {
        
        var dataEntries: [ChartDataEntry] = []
        
        for i in 0..<values.count {
            let dataEntry = ChartDataEntry(value: values[i], xIndex: i)
            dataEntries.append(dataEntry)
        }
        
        let lineChartDataSet = LineChartDataSet(yVals: dataEntries, label: "BT")
        let lineChartData = LineChartData(xVals: dataPoints, dataSet: lineChartDataSet)
        lineChartView.data = lineChartData
        
        lineChartView.xAxis.labelPosition = .Bottom
        
        let ll = ChartLimitLine(limit: 150.0, label: "Drying")
        lineChartView.rightAxis.addLimitLine(ll)
    }
    
    /******* CBCentralManagerDelegate *******/
    
    // Check status of BLE hardware
    func centralManagerDidUpdateState(central: CBCentralManager) {
        if central.state == CBCentralManagerState.PoweredOn {
            // Scan for peripherals if BLE is turned on
            central.scanForPeripheralsWithServices(nil, options: nil)
            self.statusLabel.text = "Searching for BLE Devices"
        }
        else {
            // Can have different conditions for all states if needed - show generic alert for now
            showAlertWithText("Error", message: "Bluetooth switched off or not initialized")
        }
    }
    
    
    // Check out the discovered peripherals to find Sensors
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        
        if Sensors.sensorsFound(advertisementData) == true {
            
            // Update Status Label
            self.statusLabel.text = "Sensor Found"
            
            // Stop scanning, set as the peripheral to use and establish connection
            self.centralManager.stopScan()
            self.sensorsPeripheral = peripheral
            self.sensorsPeripheral.delegate = self
            self.centralManager.connectPeripheral(peripheral, options: nil)
        }
        else {
            self.statusLabel.text = "Sensor NOT Found"
            //showAlertWithText(header: "Warning", message: "Sensors Not Found")
        }
    }
    
    // Discover services of the peripheral
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        self.statusLabel.text = "Discovering peripheral services"
        peripheral.discoverServices(nil)
    }
    
    
    // If disconnected, start searching again
    func centralManager(central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: NSError?) {
        self.statusLabel.text = "Disconnected"
        central.scanForPeripheralsWithServices(nil, options: nil)
    }
    
    /******* CBCentralPeripheralDelegate *******/
    
    // Check if the service discovered is valid
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        self.statusLabel.text = "Looking at peripheral services"
        for service in peripheral.services! {
            let thisService = service as CBService
            if Sensors.validService(thisService) {
                // Discover characteristics of all valid services
                peripheral.discoverCharacteristics(nil, forService: thisService)
            }
        }
    }
    
    
    // Enable notification and sensor for each characteristic of valid service
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        
        self.statusLabel.text = "Enabling sensors"
        
        for charateristic in service.characteristics! {
            let thisCharacteristic = charateristic as CBCharacteristic
            if Sensors.validDataCharacteristic(thisCharacteristic) {
                // Enable Sensor Notification
                self.sensorsPeripheral.setNotifyValue(true, forCharacteristic: thisCharacteristic)
                
                self.RXTXCharacteristic = (thisCharacteristic)
                
                // Enable Sensor
                let stringData = ("READ\r\n" as NSString).dataUsingEncoding(NSUTF8StringEncoding)
                self.sensorsPeripheral.writeValue(stringData!, forCharacteristic: thisCharacteristic, type: CBCharacteristicWriteType.WithResponse)
                
                var timer = NSTimer()
                timer.invalidate() // just in case not started multiple times
                // Set up sensor update timer
                timer = NSTimer.scheduledTimerWithTimeInterval(self.sensorsRequestTime, target: self, selector: #selector(self.sensorUpdate), userInfo: nil, repeats: true)
            }
        }
        
    }
    
    // Get data values when they are updated
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        
        self.statusLabel.text = "Connected"
        
        if characteristic.UUID == RXTXCharUUID {
            let arr = Sensors.getETBT(characteristic.value!)
            if Double(arr[0]) == 0.0 {
                self.ET = Double(arr[2])
                self.BT = Double(arr[1])
                self.allSensorValues[0] = self.ET
                self.allSensorValues[1] = self.BT
                
                if self.ChartValues[0] == 0.0 {
                    self.ChartValues[0] = self.BT
                } else {
                    //self.ChartValues.append(self.BT)
                }
            }
            //setChart(xAxe, values: self.ChartValues)
        }
        
        self.sensorsTableView.reloadData()
    }
    
    /******* UITableViewDataSource *******/
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allSensorLabels.count
    }
    
    /******* UITableViewDelegate *******/
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let thisCell = tableView.dequeueReusableCellWithIdentifier("sensorsCell") as! SensorsTableViewCell
        thisCell.sensorNameLabel.text = allSensorLabels[indexPath.row]
        
        let valueString = NSString(format: "%.1f", allSensorValues[indexPath.row])
        thisCell.sensorValueLabel.text = valueString as String
        
        return thisCell
    }
    
    /******* Helper *******/
    
    // Show alert
    func showAlertWithText (header : String = "Warning", message : String) {
        let alert = UIAlertController(title: header, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "Ok", style: UIAlertActionStyle.Default, handler: nil))
        alert.view.tintColor = UIColor.redColor()
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    // Set up Table View
    func setupSensorsTableView () {
        //self.sensorsTableView = UITableView()
        self.sensorsTableView.delegate = self
        self.sensorsTableView.dataSource = self
        //self.sensorsTableView.frame = CGRect(x: self.view.bounds.origin.x, y: self.statusLabel.frame.maxY+20, width: self.view.bounds.width, height: 100) //self.view.bounds.height
        self.sensorsTableView.registerClass(SensorsTableViewCell.self, forCellReuseIdentifier: "sensorsCell")
        self.sensorsTableView.tableFooterView = UIView() // to hide empty lines after cells
        self.view.addSubview(sensorsTableView)
    }
    
    @IBAction func btnStartLogPress(sender: AnyObject) {
        var timer = NSTimer()
        
        if !self.logStarted {
            self.logStarted = true
            self.chartUpdate()
            timer.invalidate() // just in case not started multiple times
            // Set up sensor update timer
            timer = NSTimer.scheduledTimerWithTimeInterval(30, target: self, selector: #selector(self.chartUpdate), userInfo: nil, repeats: true)
            //self.btnStartLog.title = "Stop"
        } else {
            self.logStarted = false
            timer.invalidate()
            //self.btnStartLog.title = "Start"
        }
    }
}
