//
//  CollectionViewController.swift
//  VirtualTourist
//
//  Created by Brian on 12/12/15.
//  Copyright © 2015 Brian King. All rights reserved.
//

import UIKit
import CoreData

class CollectionViewController: UIViewController {

	@IBOutlet weak var collectionView: UICollectionView!

	var pin: Pin!

	override func viewDidLoad() {
		super.viewDidLoad()
		collectionView.dataSource = self

		let context = pin.managedObjectContext!
		let fetchRequest = NSFetchRequest(entityName: "Photo")
		fetchRequest.predicate = NSPredicate(format: "pin = %@", argumentArray: [pin])
		context.performBlock {
			do {
				let photoList = try context.executeFetchRequest(fetchRequest) as! [Photo]
				let operation = DownloadFilesOperation(photos: photoList)
				operation.start()
			} catch {
				print("Error fetching photoList: \(error)")
			}
		}
		// Do any additional setup after loading the view, typically from a nib.
	}
}

extension CollectionViewController: UICollectionViewDataSource {

	func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return 20
	}

	func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCell", forIndexPath: indexPath)
		let imageView = UIImageView(frame: cell.contentView.frame)
		imageView.contentMode = .ScaleAspectFit
		imageView.image = UIImage(named: "Placeholder")
		cell.contentView.addSubview(imageView)
		return cell
	}
}
