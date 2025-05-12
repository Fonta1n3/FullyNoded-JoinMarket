//
//  QRDisplayerViewController.swift
//  BitSense
//
//  Created by Peter on 16/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class QRDisplayerViewController: UIViewController {
    
    var text = ""
    var tapQRGesture = UITapGestureRecognizer()
    var tapTextViewGesture = UITapGestureRecognizer()
    var headerText = ""
    var descriptionText = ""
    var headerIcon: UIImage!
    var spinner = ConnectingView()
    let qrGenerator = QRGenerator()
        
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var headerImage: UIImageView!
    

    override func viewDidLoad() {
        super.viewDidLoad()
        headerLabel.text = headerText
        headerImage.image = headerIcon
        imageView.isUserInteractionEnabled = true
        textView.text = descriptionText
        tapQRGesture = UITapGestureRecognizer(target: self, action: #selector(shareQRCode(_:)))
        imageView.addGestureRecognizer(tapQRGesture)
        
        #if DEBUG
        print("text: \(text)")
        #endif
        
        imageView.image = qR(text: text)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        text = ""
        headerText = ""
        descriptionText = ""
    }
    
    @IBAction func closeAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }
    }
    
    private func qR(text: String) -> UIImage {
        qrGenerator.textInput = text
        return qrGenerator.getQRCode()
    }
    
    @objc func shareQRCode(_ sender: UITapGestureRecognizer) {
        let objectsToShare = [imageView.image]
        let activityController = UIActivityViewController(activityItems: objectsToShare as [Any], applicationActivities: nil)
        if UIDevice.current.userInterfaceIdiom == .pad {
            activityController.popoverPresentationController?.sourceView = self.view
            activityController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        }
        self.present(activityController, animated: true) {}
    }
    
    private func showQR(_ string: String) {
        qrGenerator.textInput = string
        imageView.image = qrGenerator.getQRCode()
    }
}
