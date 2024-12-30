//
//  ViewController.swift
//  SwipeClean
//
//  Created by Memo on 2024-12-30.
//

import UIKit
import Photos

class ViewController: UIViewController {

    @IBOutlet weak var photoImageView: UIImageView!
    @IBOutlet weak var FinishSwiping: UIButton!
    
    var deletedPhotos: [PHAsset] = [] // Photos marked for deletion
    var toBeDeleted: [PHAsset] = [] // Photos queued for deletion
    var currentPhotoIndex = 0
    var allPhotos: PHFetchResult<PHAsset>?

    override func viewDidLoad() {
        super.viewDidLoad()
        requestPhotoLibraryAccess()

        FinishSwiping.isHidden = true

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        photoImageView.addGestureRecognizer(panGesture)
        photoImageView.isUserInteractionEnabled = true
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let imageView = photoImageView!
        
        switch gesture.state {
        case .changed:
            imageView.center = CGPoint(x: view.center.x + translation.x, y: view.center.y + translation.y)
            let rotation = translation.x / view.frame.width * 0.25
            imageView.transform = CGAffineTransform(rotationAngle: rotation)
            
        case .ended:
            FinishSwiping.isHidden = false
            
            if abs(translation.x) > 100 {
                let isLeftSwipe = translation.x < 0
                let offScreenX = isLeftSwipe ? -view.frame.width : view.frame.width
                UIView.animate(withDuration: 0.3, animations: {
                    imageView.center = CGPoint(x: offScreenX, y: imageView.center.y)
                    imageView.alpha = 0
                }, completion: { _ in
                    if isLeftSwipe {
                        self.markForDeletion()
                    } else {
                        self.loadNextPhoto()
                    }
                    self.resetImageView()
                })
            } else {
                resetImageView()
            }
            
        default:
            break
        }
    }

    func resetImageView() {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
            self.photoImageView.center = self.view.center
            self.photoImageView.transform = .identity
            self.photoImageView.alpha = 1
        }, completion: nil)
    }
    
    func requestPhotoLibraryAccess() {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                DispatchQueue.main.async {
                    self.fetchAllPhotos()
                    self.displayPhoto(at: self.currentPhotoIndex)
                }
            } else {
                print("Access to photo library denied.")
            }
        }
    }

    func fetchAllPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        allPhotos = PHAsset.fetchAssets(with: .image, options: fetchOptions)
    }

    func displayPhoto(at index: Int) {
        guard let allPhotos = allPhotos, index < allPhotos.count else {
            print("No more photos to display.")
            photoImageView.image = nil
            return
        }

        let asset = allPhotos.object(at: index)
        let imageManager = PHImageManager.default()
        imageManager.requestImage(for: asset,
                                  targetSize: photoImageView.bounds.size,
                                  contentMode: .aspectFill,
                                  options: nil) { image, _ in
            self.photoImageView.image = image
        }
    }

    func markForDeletion() {
        guard let allPhotos = allPhotos, currentPhotoIndex < allPhotos.count else { return }
        let assetToDelete = allPhotos.object(at: currentPhotoIndex)
        toBeDeleted.append(assetToDelete)

        print("Photo added to deletion queue. Total photos to delete: \(toBeDeleted.count)")
        print("Current photo to delete: \(assetToDelete)")

        loadNextPhoto()
    }


    func loadNextPhoto() {
        currentPhotoIndex += 1
        displayPhoto(at: currentPhotoIndex)
    }
    
    @IBAction func finishSwipingPressed(_ sender: Any) {
        guard !toBeDeleted.isEmpty else {
            print("No photos to delete.")
            return
        }

        print("Attempting to delete \(toBeDeleted.count) photos.")
        print("Photos queued for deletion: \(toBeDeleted)")

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(self.toBeDeleted as NSArray)
        }) { success, error in
            if success {
                print("Deleted \(self.toBeDeleted.count) photos.")
                self.toBeDeleted.removeAll()
                
                DispatchQueue.main.async {
                    self.FinishSwiping.isHidden = true
                }
            } else if let error = error {
                print("Error deleting photos: \(error.localizedDescription)")
            }
        }
    }
}
