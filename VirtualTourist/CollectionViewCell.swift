//
//  CollectionViewCell.swift
//  VirtualTourist
//
//  Created by Brian on 02/01/16.
//  Copyright © 2016 Brian King. All rights reserved.
//

import UIKit

class CollectionViewCell: UICollectionViewCell {
	var imageView: UIImageView!

	override init(frame: CGRect) {
		super.init(frame: frame)
		self.addImageView()
	}

	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		self.addImageView()
	}

	func addImageView() {
		imageView = UIImageView(frame: contentView.frame)
		imageView.contentMode = .ScaleAspectFit
		contentView.addSubview(imageView)
	}
}
