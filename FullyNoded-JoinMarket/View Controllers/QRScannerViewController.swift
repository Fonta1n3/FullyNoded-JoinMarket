//
//  QRScannerViewController.swift
//  BitSense
//
//  Created by Peter on 16/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import AVFoundation
import UIKit

@available(macCatalyst 14.0, *)
class QRScannerViewController: UIViewController {
    
    private var hasScanned = false
    private let avCaptureSession = AVCaptureSession()
    private var stringToReturn = ""
    private let imagePicker = UIImagePickerController()
    private var qrString = ""
    private let uploadButton = UIButton()
    private let torchButton = UIButton()
    private let closeButton = UIButton()
    private let downSwipe = UISwipeGestureRecognizer()
    var onDoneBlock : ((String?) -> Void)?
    private let spinner = ConnectingView()
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    private var blurArray = [UIVisualEffectView]()
    private var isTorchOn = Bool()
    
    @IBOutlet weak private var scannerView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureScanner()
        spinner.addConnectingView(vc: self, description: "")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        scanNow()
    }
    
    @IBAction func closeAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.removeScanner()
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    
    private func scanNow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.scanQRCode()
            self.addScannerButtons()
            self.scannerView.addSubview(self.closeButton)
            self.spinner.removeConnectingView()
        }
    }
    
    private func configureScanner() {
        scannerView.isUserInteractionEnabled = true
        uploadButton.addTarget(self, action: #selector(chooseQRCodeFromLibrary), for: .touchUpInside)
        torchButton.addTarget(self, action: #selector(toggleTorchNow), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(back), for: .touchUpInside)
        isTorchOn = false
        configureImagePicker()
        configureUploadButton()
        configureTorchButton()
        configureCloseButton()
        configureDownSwipe()
    }
    
    private func addScannerButtons() {
        addBlurView(frame: CGRect(x: scannerView.frame.maxX - 80, y: scannerView.frame.maxY - 80, width: 70, height: 70), button: uploadButton)
        addBlurView(frame: CGRect(x: 10, y: scannerView.frame.maxY - 80, width: 70, height: 70), button: torchButton)
    }
    
    private func didPickImage() {
        process(text: qrString)
    }
    
    @objc func chooseQRCodeFromLibrary() {
        present(imagePicker, animated: true, completion: nil)
    }
    
    @objc func toggleTorchNow() {
        if isTorchOn {
            toggleTorch(on: false)
            isTorchOn = false
        } else {
            toggleTorch(on: true)
            isTorchOn = true
        }
    }
    
    private func addBlurView(frame: CGRect, button: UIButton) {
        button.removeFromSuperview()
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
        blur.frame = frame
        blur.clipsToBounds = true
        blur.layer.cornerRadius = frame.width / 2
        blur.contentView.addSubview(button)
        blurArray.append(blur)
        scannerView.addSubview(blur)
    }
    
    @objc func back() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.avCaptureSession.stopRunning()
            vc.dismiss(animated: true, completion: nil)
        }
    }
    
    private func stopScanning(_ psbt: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.removeScanner()
            
            self.dismiss(animated: true) {
                self.onDoneBlock!(psbt)
            }
        }
    }
            
    private func uniq<S : Sequence, T : Hashable>(source: S) -> [T] where S.Iterator.Element == T {
        var buffer = [T]()
        var added = Set<T>()
        for elem in source {
            if !added.contains(elem) {
                buffer.append(elem)
                added.insert(elem)
            }
        }
        return buffer
    }
            
    private func process(text: String) {
        #if DEBUG
        print("text: \(text)")
        #endif
        
        DispatchQueue.main.async { [unowned vc = self] in
            vc.dismiss(animated: true) {
                vc.stopScanner()
                vc.onDoneBlock!(text)
            }
        }
    }
    
    @objc func handleSwipes(_ sender: UIGestureRecognizer) {
        stopScanner()
    }
    
    private func configureCloseButton() {
        closeButton.frame = CGRect(x: view.frame.midX - 15, y: view.frame.maxY - 150, width: 30, height: 30)
        closeButton.setImage(UIImage(named: "Image-10"), for: .normal)
    }
    
    private func configureTorchButton() {
        torchButton.frame = CGRect(x: 17.5, y: 17.5, width: 35, height: 35)
        torchButton.setImage(UIImage(named: "strobe.png"), for: .normal)
        addShadow(view: torchButton)
    }
    
    private func configureUploadButton() {
        uploadButton.frame = CGRect(x: 17.5, y: 17.5, width: 35, height: 35)
        uploadButton.setImage(UIImage(named: "images.png"), for: .normal)
        addShadow(view: uploadButton)
    }
    
    private func addShadow(view: UIView) {
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 1.5, height: 1.5)
        view.layer.shadowRadius = 1.5
        view.layer.shadowOpacity = 0.5
    }
    
    private func configureImagePicker() {
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
    }
    
    private func configureDownSwipe() {
        downSwipe.direction = .down
        downSwipe.addTarget(self, action: #selector(handleSwipes(_:)))
        scannerView.addGestureRecognizer(downSwipe)
    }
    
    private func toggleTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                
                if on {
                    device.torchMode = .on
                } else {
                    device.torchMode = .off
                }
                
                device.unlockForConfiguration()
            } catch {
                print("Torch could not be used")
            }
            
        } else {
            print("Torch is not available")
        }
    }
    
    private func scanQRCode() {
        let queue = DispatchQueue(label: "codes", qos: .userInteractive)
        
        guard let avCaptureDevice = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        
        guard let avCaptureInput = try? AVCaptureDeviceInput(device: avCaptureDevice) else { return }
        
        let avCaptureMetadataOutput = AVCaptureMetadataOutput()
        avCaptureMetadataOutput.setMetadataObjectsDelegate(self, queue: queue)
        
        if let inputs = self.avCaptureSession.inputs as? [AVCaptureDeviceInput] {
            for input in inputs {
                self.avCaptureSession.removeInput(input)
            }
        }
        
        if let outputs = self.avCaptureSession.outputs as? [AVCaptureMetadataOutput] {
            for output in outputs {
                self.avCaptureSession.removeOutput(output)
            }
        }
        
        self.avCaptureSession.addInput(avCaptureInput)
        self.avCaptureSession.addOutput(avCaptureMetadataOutput)
        avCaptureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
        let avCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: avCaptureSession)
        avCaptureVideoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        avCaptureVideoPreviewLayer.frame = self.scannerView.bounds
        self.scannerView.layer.addSublayer(avCaptureVideoPreviewLayer)
        self.startScanner()
    }
    
    private func removeScanner() {
        stopScanner()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.torchButton.removeFromSuperview()
            self.uploadButton.removeFromSuperview()
        }
    }
    
    private func stopScanner() {
        DispatchQueue.background(delay: 0.0, completion:  { [weak self] in
            guard let self = self else { return }
            self.avCaptureSession.stopRunning()
        })
    }
    
    private func startScanner() {
        DispatchQueue.background(delay: 0.0, completion:  { [weak self] in
            guard let self = self else { return }
            self.avCaptureSession.startRunning()
        })
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
    return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
    return input.rawValue
}

@available(macCatalyst 14.0, *)
extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if !hasScanned {
            guard metadataObjects.count > 0, let machineReadableCode = metadataObjects[0] as? AVMetadataMachineReadableCodeObject, machineReadableCode.type == AVMetadataObject.ObjectType.qr, let stringURL = machineReadableCode.stringValue else {
                
                return
            }
            
            hasScanned = true
                        
            process(text: stringURL)
        }
    }
}

@available(macCatalyst 14.0, *)
extension QRScannerViewController: UIImagePickerControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        // Local variable inserted by Swift 4.2 migrator.
        let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)
        
        guard let pickedImage = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage,
            let detector:CIDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy:CIDetectorAccuracyHigh]),
            let ciImage:CIImage = CIImage(image:pickedImage),
            let features = detector.features(in: ciImage) as? [CIQRCodeFeature] else {
            
            return
        }
        
        var qrCodeLink = ""
        
        for feature in features {
            qrCodeLink += feature.messageString!
        }
        
        DispatchQueue.main.async {
            let impact = UIImpactFeedbackGenerator()
            impact.impactOccurred()
            AudioServicesPlaySystemSound(1103)
        }
        
        picker.dismiss(animated: true, completion: { [weak self] in
            guard let self = self else { return }
            
            self.process(text: qrCodeLink)
        })
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) {
            DispatchQueue.main.async { [weak self] in
                self?.dismiss(animated: true, completion: nil)
            }
        }
    }
    
}

extension DispatchQueue {

    static func background(delay: Double = 0.0, background: (()->Void)? = nil, completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
            background?()
            if let completion = completion {
                    completion()
            }
        }
    }
}

extension String {

    var length: Int {
        return count
    }

    subscript (i: Int) -> String {
        return self[i ..< i + 1]
    }

    func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, length) ..< length]
    }

    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }

    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
}

@available(macCatalyst 14.0, *)
extension QRScannerViewController: UINavigationControllerDelegate {}
