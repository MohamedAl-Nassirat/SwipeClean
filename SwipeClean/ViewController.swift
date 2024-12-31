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
    @IBOutlet weak var ConfirmIcon: UIImageView!
    @IBOutlet weak var TrashIcon: UIImageView!
    @IBOutlet weak var yearsTableView: UITableView!
    
    var deletedPhotos: [PHAsset] = [] // Photos marked for deletion
    var toBeDeleted: [PHAsset] = [] // Photos queued for deletion
    var currentPhotoIndex = 0
    var allPhotos: PHFetchResult<PHAsset>?
    var filteredPhotos: [PHAsset] = [] // Filtered photos for the selected year
    var years: [String] = [] // Available years in the photo library

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup table view
        yearsTableView.delegate = self
        yearsTableView.dataSource = self
        yearsTableView.isHidden = false

        // Hide buttons and icons initially
        self.FinishSwiping.isHidden = true
        self.ConfirmIcon.isHidden = true
        self.TrashIcon.isHidden = true

        // Gesture recognizer for swiping
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        photoImageView.addGestureRecognizer(panGesture)
        photoImageView.isUserInteractionEnabled = true

        requestPhotoLibraryAccess()
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let imageView = photoImageView!

        switch gesture.state {
        case .changed:
            // Move the image view with the swipe
            imageView.center = CGPoint(x: view.center.x + translation.x, y: view.center.y + translation.y)
            let rotation = translation.x / view.frame.width * 0.25
            imageView.transform = CGAffineTransform(rotationAngle: rotation)

            // Determine the direction of the swipe and show the appropriate icon
            if translation.x > 0 {
                ConfirmIcon.isHidden = false
                TrashIcon.isHidden = true
            } else {
                TrashIcon.isHidden = false
                ConfirmIcon.isHidden = true
            }

        case .ended:
            // Show the "Finish Swiping" button after the first swipe
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
        }, completion: { _ in
            self.ConfirmIcon.isHidden = true
            self.TrashIcon.isHidden = true
        })
    }
    
    func requestPhotoLibraryAccess() {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                DispatchQueue.main.async {
                    self.fetchAllPhotos()
                    self.yearsTableView.reloadData() // Refresh years in the table view
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
        
        guard let allPhotos = allPhotos else { return }
        
        var yearSet = Set<String>() // To store unique years
        allPhotos.enumerateObjects { asset, _, _ in
            if let creationDate = asset.creationDate {
                let year = Calendar.current.component(.year, from: creationDate)
                yearSet.insert("\(year)")
            }
        }
        
        years = Array(yearSet).sorted(by: >) // Sort years in descending order
        print("Available Years: \(years)") // Debugging
    }

    func displayPhoto(at index: Int) {
        guard index < filteredPhotos.count else {
            print("No more photos to display.")
            photoImageView.image = nil
            return
        }

        let asset = filteredPhotos[index]
        let imageManager = PHImageManager.default()
        imageManager.requestImage(for: asset,
                                  targetSize: photoImageView.bounds.size,
                                  contentMode: .aspectFill,
                                  options: nil) { image, _ in
            self.photoImageView.image = image
        }
    }

    func markForDeletion() {
        guard currentPhotoIndex < filteredPhotos.count else { return }
        let assetToDelete = filteredPhotos[currentPhotoIndex]
        toBeDeleted.append(assetToDelete)

        print("Photo added to deletion queue. Total photos to delete: \(toBeDeleted.count)")

        loadNextPhoto()
    }

    func loadNextPhoto() {
        currentPhotoIndex += 1
        displayPhoto(at: currentPhotoIndex)
    }
    
    func filterPhotos(byYear year: String) {
        guard let allPhotos = allPhotos else { return }

        filteredPhotos = allPhotos.objects(at: IndexSet(0..<allPhotos.count)).filter {
            if let creationDate = $0.creationDate {
                let assetYear = Calendar.current.component(.year, from: creationDate)
                return "\(assetYear)" == year
            }
            return false
        }

        print("Filtered \(filteredPhotos.count) photos for the year \(year).")
        currentPhotoIndex = 0
        displayPhoto(at: currentPhotoIndex)
    }

    @IBAction func finishSwipingPressed(_ sender: Any) {
        guard !toBeDeleted.isEmpty else {
            print("No photos to delete.")
            return
        }

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

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return years.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "YearCell", for: indexPath)
        cell.textLabel?.text = years[indexPath.row]
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedYear = years[indexPath.row]
        print("Selected Year: \(selectedYear)")
        filterPhotos(byYear: selectedYear)
        tableView.isHidden = true // Hide table after selection
    }
}
