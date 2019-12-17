//
//  ViewController.swift
//  fuckin_acceleration
//
//  Created by 皆川泰陽 on 2019/11/11.
//  Copyright © 2019 皆川泰陽. All rights reserved.
//

import UIKit
import CoreMotion
import Charts

private class CubicLineSampleFillFormatter: IFillFormatter {
    func getFillLinePosition(dataSet: ILineChartDataSet, dataProvider: LineChartDataProvider) -> CGFloat {
        return -10
    }
}

class ViewController: UIViewController, ChartViewDelegate {
    let motion = CMMotionManager()
    var timer: Timer?
    @IBOutlet weak var zAccLabel: UILabel!
    @IBOutlet weak var lineChartView: LineChartView!
    
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var stopButton: UIButton!
    var fileName = "test4.txt"
    @IBOutlet weak var fileNameField: UITextField!
    @IBOutlet weak var readFileNameField: UITextField!
    @IBOutlet weak var readFileButton: UIButton!
    @IBOutlet weak var androidSwitch: UISwitch!
    
    
    let fm = FileManager.default
    let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.lineChartView.delegate = self
        
        self.lineChartView.dragEnabled = false
        self.lineChartView.setScaleEnabled(true)
        self.lineChartView.pinchZoomEnabled = false
        self.lineChartView.maxHighlightDistance = 300
        
        self.lineChartView.xAxis.enabled = true
        
        let yAxis = self.lineChartView.leftAxis
        yAxis.labelFont = UIFont(name: "HelveticaNeue-Light", size:12)!
        yAxis.setLabelCount(10, force: false)
        yAxis.labelTextColor = .black
        yAxis.labelPosition = .outsideChart
        yAxis.axisLineColor = .white
        
        yAxis.axisMaximum = 0.0
        yAxis.axisMinimum = -2.0
        
        self.lineChartView.rightAxis.enabled = false
        self.lineChartView.legend.enabled = false
        
        self.stopButton.isHidden = true
    }
    
    
    func generateLineData(vals: [Double]) -> LineChartData {
        let yVal = vals.enumerated().map { (i, val) -> ChartDataEntry in
            ChartDataEntry(x: Double(i)/1000, y: val)
        }
        let set = LineChartDataSet(entries: yVal)
        set.mode = .cubicBezier
        set.drawCirclesEnabled = false
        set.lineWidth = 1.8
        set.circleRadius = 5
        set.setCircleColor(.white)
//        set.highlightColor = UIColor(red: 244/255, green: 117/255, blue: 117/255, alpha: 1)
//        set.fillColor = .white
//        set.fillAlpha = 1
        set.drawHorizontalHighlightIndicatorEnabled = false
        set.fillFormatter = CubicLineSampleFillFormatter()
        
        let data = LineChartData(dataSet: set)
        data.setDrawValues(false)
        //データを返す。
        return data
    }
    

    
    
    var xAcc: [Double] = []
    var yAcc: [Double] = []
    var zAcc: [Double] = []
    
    func startDeadReckoning() {
        // Make sure the accelerometer hardware is available.
        if self.motion.isAccelerometerAvailable &&
        self.motion.isGyroAvailable &&
        self.motion.isMagnetometerAvailable &&
        self.motion.isDeviceMotionAvailable {
            let Hz = 50
            self.motion.deviceMotionUpdateInterval = 1.0 / Double(Hz)
            self.motion.magnetometerUpdateInterval = 1.0 / Double(100)
            self.motion.startMagnetometerUpdates()
            
            self.zAccLabel.text = "サンプリング周波数 \(Hz) Hz"
            
            self.motion.startDeviceMotionUpdates(to: .init()) { (CMDeviceMotion, Err) in
                let nowWorldTime = NSDate().timeIntervalSince1970
                guard let deviceMotion = CMDeviceMotion else { return }
                //print(deviceMotion.timestamp)
                // RotationMatrix の取得
                // [m11, m12, m13, m21, m22, m23, m31, m32, m33]
                let rm = deviceMotion.attitude.rotationMatrix
                let rotationMatrix = [rm.m11, rm.m12, rm.m13, rm.m21, rm.m22, rm.m23, rm.m31, rm.m32, rm.m33]
                // ユーザー加速度の取得 [G]
                let userAcc = deviceMotion.userAcceleration
                // 重力加速度の取得 [G]
                let gravity = deviceMotion.gravity
                // バイアスを削除したジャイロの取得 [rad/s]
                let gyroscope = deviceMotion.rotationRate
                // Raw磁場の取得 [マイクロテスラ]
                let magnetic = self.motion.magnetometerData?.magneticField ?? CMMagneticField.init()
                
                
                // 別で開く
                DispatchQueue.init(label: "fileWrite").async {
                    self.writeFile(time: nowWorldTime, RM: rotationMatrix, userAcc: userAcc, gravity: gravity, gyroscope: gyroscope, magnetic: magnetic)
                }
            }
            
            self.timer = Timer(fire: Date(), interval: 1.0/Double(Hz), repeats: true, block: { (_) in
                // グラフ描画
                if self.xAcc.count == (Hz) {
                    let tmp_zAcc = self.zAcc
                    DispatchQueue.main.async {
                        self.lineChartView.data = self.generateLineData(vals: tmp_zAcc)
                    }
                    self.xAcc.removeAll()
                    self.yAcc.removeAll()
                    self.zAcc.removeAll()
                }
            })
        }
    }
    
    func writeFile(time: TimeInterval, RM: [Double], userAcc: CMAcceleration, gravity: CMAcceleration, gyroscope: CMRotationRate, magnetic: CMMagneticField) {
        let fm = FileManager.default
        let documentsUrl = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileUrl = documentsUrl.appendingPathComponent(self.fileName)
        if fm.fileExists(atPath: fileUrl.path) {
            if let fileHandle = FileHandle(forWritingAtPath: fileUrl.path) {
                fileHandle.seekToEndOfFile()
                // let data = "test append2 write data!".data(using: .utf8)!
                var writeString = "\(time),"
                writeString.append(RM.map(){ String($0) }.joined(separator: ","))
                writeString.append(contentsOf: ",\(userAcc.x),\(userAcc.y),\(userAcc.z),\(gravity.x),\(gravity.y),\(gravity.z),")
                writeString.append(contentsOf: "\(gyroscope.x),\(gyroscope.y),\(gyroscope.z),\(magnetic.x),\(magnetic.y),\(magnetic.z)\n")
                // データ書き込み
                fileHandle.write(writeString.data(using: .utf8)!)
                fileHandle.closeFile()
            }
        }
    }
    
    @IBAction func startRecord(_ sender: Any) {
        self.fileName = self.fileNameField.text!
        let fileUrl = documentsUrl.appendingPathComponent(self.fileName)
        if !fm.fileExists(atPath: fileUrl.path) {
            let data = "timestamp,rm_m11,rm_m12,rm_m13,rm_m21,rm_m22,rm_m23,rm_m31,rm_m32,rm_m33,userAcc_x,userAcc_y,userAcc_z,gravity_x,gravity_y,gravity_z,gyro_x,gyro_y,gyro_z,mag_x,mag_y,mag_z\n".data(using: .utf8)!
            try! data.write(to: fileUrl)
        }
        self.startButton.isHidden = true
        self.fileNameField.isHidden = true
        self.stopButton.isHidden = false
        self.readFileNameField.isHidden = true
        self.readFileButton.isHidden = true
        self.startDeadReckoning()
    }
    
    @IBAction func stopRecord(_ sender: Any) {
        if self.timer!.isValid {
            self.timer!.invalidate()
        }
        self.motion.stopDeviceMotionUpdates()
        self.motion.stopMagnetometerUpdates()
        self.startButton.isHidden = false
        self.stopButton.isHidden = true
        self.fileNameField.text = ""
        self.fileNameField.isHidden = false
        self.readFileButton.isHidden = false
        self.readFileNameField.isHidden = false
    }
    
    // これはiOS生成のファイルを使うやつ
    @IBAction func readFile(_ sender: Any) {
        guard let fileName = self.readFileNameField.text else { return }
        let fm = FileManager.default
        let documentUrl = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileUrl = documentUrl.appendingPathComponent(fileName)
        guard fm.fileExists(atPath: fileUrl.path) else { return }
        guard let data = try? String(contentsOf: fileUrl, encoding: .utf8) else { return }
        
        self.startButton.isHidden = true
        self.stopButton.isHidden = true
        self.readFileButton.isHidden = true
        
        // 書き込みファイルの作成
        self.createDROutputFile(fileName: fileName)
        // ファイルの読み込みとDR準備
        let PF = ParticleFilter(particleCount: 100, alpha: 0, sigma: 0.001)
        
        if androidSwitch.isOn {
            data.components(separatedBy: "\n").forEach { (rowString) in
                let csvItems = rowString.components(separatedBy: ",").map({ Double($0) })
                guard csvItems.count == 22 else { return }
                guard let m11 = csvItems[1],
                    let m12 = csvItems[2],
                    let m13 = csvItems[3],
                    let m21 = csvItems[4],
                    let m22 = csvItems[5],
                    let m23 = csvItems[6],
                    let m31 = csvItems[7],
                    let m32 = csvItems[8],
                    let m33 = csvItems[9] else { return }
                // 以後nilは存在しない
                let userAcc = CMAcceleration(x: csvItems[10]!, y: csvItems[11]!, z: csvItems[12]!)
                let gravity = CMAcceleration(x: csvItems[13]!, y: csvItems[14]!, z: csvItems[15]!)
                let gyro = CMRotationRate(x: csvItems[16]!, y: csvItems[17]!, z: csvItems[18]!)
                let magnetic = CMMagneticField(x: csvItems[19]!, y: csvItems[20]!, z: csvItems[21]!)
                let rotationMatrix = CMRotationMatrix([m11, m12, m13, m21, m22, m23, m31, m32, m33])!
                // 端末座標軸 -> 世界座標軸
                let worldAcc = convertUserAccToWorldAxes(userAcc: userAcc, rotationMatrix: rotationMatrix)
                // DRをする
                PF.run(input: worldAcc)
            }
        } else {
            data.components(separatedBy: "\n").forEach { (rowString) in
                let csvItems = rowString.components(separatedBy: ",").map({ Double($0) })
                guard csvItems.count == 22 else { return }
                guard let m11 = csvItems[1],
                    let m12 = csvItems[2],
                    let m13 = csvItems[3],
                    let m21 = csvItems[4],
                    let m22 = csvItems[5],
                    let m23 = csvItems[6],
                    let m31 = csvItems[7],
                    let m32 = csvItems[8],
                    let m33 = csvItems[9] else { return }
                // 以後nilは存在しない
                let userAcc = CMAcceleration(x: csvItems[10]!, y: csvItems[11]!, z: csvItems[12]!)
                let gravity = CMAcceleration(x: csvItems[13]!, y: csvItems[14]!, z: csvItems[15]!)
                let gyro = CMRotationRate(x: csvItems[16]!, y: csvItems[17]!, z: csvItems[18]!)
                let magnetic = CMMagneticField(x: csvItems[19]!, y: csvItems[20]!, z: csvItems[21]!)
                let rotationMatrix = CMRotationMatrix([m11, m12, m13, m21, m22, m23, m31, m32, m33])!
                // 端末座標軸 -> 世界座標軸
                let worldAcc = convertUserAccToWorldAxes(userAcc: userAcc, rotationMatrix: rotationMatrix)
                // DRをする
                PF.run(input: worldAcc)
            }
        }
        self.startButton.isHidden = false
        self.stopButton.isHidden = false
        self.readFileButton.isHidden = false
    }
    
    func createDROutputFile(fileName: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "mm-dd_HH:mm"
        let fileName = "DR_\(dateFormatter.string(from: Date()))_\(fileName)"
        let fileUrl = documentsUrl.appendingPathComponent(fileName)

        let data = "DR_speed_x,DR_speed_y,DR_speed_z,DR_acc_x,DR_acc_y,DR_acc_z\n".data(using: .utf8)!
        try! data.write(to: fileUrl)
    }
    
    func convertUserAccToWorldAxes(userAcc: CMAcceleration, rotationMatrix: CMRotationMatrix) -> CMAcceleration {
        let rm = rotationMatrix.toArray()
        // 端末を縦持ちし，揺らした際（y軸の移動）に変換後はz軸で揺れるように変換する
        // 列別に掛け算
        let multipleColumn: [Double] = rm.enumerated().map { (index, element) -> Double in
            switch (index%3) {
            case 0: return element * userAcc.x
            case 1: return element * userAcc.y
            case 2: return element * userAcc.z
            default:
                return 0.0
            }
        }
        
        return userAcc
    }
}

extension CMRotationMatrix {
    func toArray() -> [Double] {
        return [self.m11, self.m12, self.m13, self.m21, self.m22, self.m23, self.m31, self.m32, self.m33]
    }
    
    init?(_ input: [Double]) {
        if input.count != 9 {
            return nil
        }
        self.init()
        self.m11 = input[0]
        self.m12 = input[1]
        self.m13 = input[3]
        self.m21 = input[4]
        self.m22 = input[5]
        self.m23 = input[6]
        self.m31 = input[7]
        self.m32 = input[8]
        self.m33 = input[9]
    }
}
