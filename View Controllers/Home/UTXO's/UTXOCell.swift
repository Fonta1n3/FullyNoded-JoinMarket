//
//  UTXOCell.swift
//  FullyNoded
//
//  Created by FeedMyTummy on 9/16/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

protocol UTXOCellDelegate: AnyObject {
    func didTapToFreeze(_ utxo: JMUtxo)
    func didTapToUnfreeze(_ utxo: JMUtxo)
}

class UTXOCell: UITableViewCell {
    
    static let identifier = "UTXOCell"
    private var utxo: JMUtxo!
    private var isLocked: Bool!
    private unowned var delegate: UTXOCellDelegate!
    
    @IBOutlet private weak var frozenLabel: UILabel!
    @IBOutlet private weak var lockedImage: UIImageView!
    @IBOutlet private weak var confsImage: UIImageView!
    @IBOutlet private weak var locktimeOutlet: UILabel!
    @IBOutlet private weak var unfreezeOutlet: UIButton!
    @IBOutlet private weak var freezeOutlet: UIButton!
    @IBOutlet private weak var labelOutlet: UILabel!
    @IBOutlet private weak var addressLabel: UILabel!
    @IBOutlet public weak var roundeBackgroundView: UIView!
    @IBOutlet private weak var confirmationsLabel: UILabel!
    @IBOutlet private weak var amountLabel: UILabel!
    @IBOutlet private weak var derivationLabel: UILabel!
    @IBOutlet private weak var mixdepthOutlet: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        layer.borderColor = UIColor.lightGray.cgColor
        layer.borderWidth = 0.5
        layer.cornerRadius = 8
        
        //roundeBackgroundView.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        
        selectionStyle = .none
    }
    
    func configure(utxo: JMUtxo, fxRate: Double?, delegate: UTXOCellDelegate) {
        self.utxo = utxo
        self.delegate = delegate
        
        if utxo.label != "" {
            labelOutlet.text = utxo.label
        } else {
            labelOutlet.text = "No label"
        }
        
        if utxo.frozen {
            frozenLabel.text = "Frozen"
        } else {
            frozenLabel.text = "Not frozen"
        }
        
        if let locktime = utxo.locktime {
            locktimeOutlet.text = "Locked until \(locktime)"
            lockedImage.tintColor = .systemOrange
        } else {
            locktimeOutlet.text = ""
            lockedImage.tintColor = .clear
        }
        
        mixdepthOutlet.text = "\(utxo.mixdepth)"
        
        if utxo.frozen {
            freezeOutlet.alpha = 0.2
            freezeOutlet.isEnabled = false
            unfreezeOutlet.alpha = 1
            unfreezeOutlet.isEnabled = true
            
        } else {
            freezeOutlet.alpha = 1
            freezeOutlet.isEnabled = true
            unfreezeOutlet.alpha = 0.2
            unfreezeOutlet.isEnabled = false
        }
        

        derivationLabel.text = utxo.path
        addressLabel.text = utxo.address.withSpaces
        
        amountLabel.text = utxo.value.satsToBtcDouble.btcBalanceWithSpaces
        if let fxRate = fxRate {
            amountLabel.text! += "  ~\((utxo.value.satsToBtcDouble * fxRate).fiatString)"
        }
        
        if utxo.confirmations == 0 {
            confsImage.tintColor = .systemRed
        } else {
            confsImage.tintColor = .systemGreen
        }
        
        confirmationsLabel.text = "\(utxo.confirmations) confs"
    }
    
    @IBAction func freezeAction(_ sender: Any) {
        delegate.didTapToFreeze(utxo)
    }
    
    @IBAction func unfreezeAction(_ sender: Any) {
        delegate.didTapToUnfreeze(utxo)
    }
    
}
