//
//  UTXOCell.swift
//  FullyNoded
//
//  Created by FeedMyTummy on 9/16/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

protocol UTXOCellDelegate: AnyObject {
//    func didTapToLock(_ utxo: Utxo)
}

class UTXOCell: UITableViewCell {
    
    static let identifier = "UTXOCell"
    private var utxo: JMUtxo!
    private var isLocked: Bool!
    private unowned var delegate: UTXOCellDelegate!
    
    @IBOutlet private weak var labelOutlet: UILabel!
    @IBOutlet private weak var addressLabel: UILabel!
    @IBOutlet public weak var roundeBackgroundView: UIView!
    @IBOutlet public weak var checkMarkImageView: UIImageView!
    @IBOutlet private weak var confirmationsLabel: UILabel!
    @IBOutlet private weak var amountLabel: UILabel!
    @IBOutlet private weak var isChangeBackground: UIView!
    @IBOutlet private weak var isChangeImageView: UIImageView!
    @IBOutlet private weak var lockButtonOutlet: UIButton!
    @IBOutlet private weak var derivationLabel: UILabel!
    @IBOutlet private weak var mixdepthOutlet: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        layer.borderColor = UIColor.lightGray.cgColor
        layer.borderWidth = 0.5
        layer.cornerRadius = 8
        
        roundeBackgroundView.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        isChangeBackground.clipsToBounds = true
        isChangeBackground.layer.cornerRadius = 5
        isChangeImageView.tintColor = .white
        
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
        
        mixdepthOutlet.text = "Mixdepth: \(utxo.mixdepth)"
        
        if utxo.frozen {
            lockButtonOutlet.setImage(UIImage(systemName: "snowflake"), for: .normal)
            lockButtonOutlet.tintColor = .white
            lockButtonOutlet.alpha = 1
        } else {
            lockButtonOutlet.alpha = 0
        }
        
        if utxo.path.contains("/1/") {
            isChangeImageView.image = UIImage(systemName: "arrow.2.circlepath")
            isChangeBackground.backgroundColor = .systemPurple
            
        } else {
            isChangeImageView.image = UIImage(systemName: "arrow.down.left")
            isChangeBackground.backgroundColor = .systemBlue
        }
        derivationLabel.text = utxo.path
        addressLabel.text = utxo.address
        amountLabel.text = utxo.value.satsToBtcDouble.btcBalanceWithSpaces
       
        if utxo.isSelected {
            checkMarkImageView.alpha = 1
            self.roundeBackgroundView.backgroundColor = .darkGray
        } else {
            checkMarkImageView.alpha = 0
            self.roundeBackgroundView.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        }
        
        if utxo.confirmations == 0 {
            confirmationsLabel.textColor = .systemRed
        } else {
            confirmationsLabel.textColor = .systemGreen
        }
        
        confirmationsLabel.text = "\(utxo.confirmations) confs"
    }
    
    func selectedAnimation() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            UIView.animate(withDuration: 0.2, animations: {
                self.alpha = 0
            }) { _ in
                UIView.animate(withDuration: 0.2, animations: {
                    self.alpha = 1
                    self.checkMarkImageView.alpha = 1
                    self.roundeBackgroundView.backgroundColor = .darkGray
                    
                })
            }
        }
    }
    
    func deselectedAnimation() {
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2, animations: { [weak self] in
                guard let self = self else { return }
                
                self.checkMarkImageView.alpha = 0
                self.alpha = 0
            }) { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    self.alpha = 1
                    self.roundeBackgroundView.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
                    
                })
            }
        }
    }
    
//    @IBAction func lockButtonTapped(_ sender: Any) {
//        //delegate.didTapToLock(utxo)
//    }
    
}
