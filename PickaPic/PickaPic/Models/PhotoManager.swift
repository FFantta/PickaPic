import SwiftUI
import Photos

class PhotoManager: ObservableObject {
    @Published var dailyPhotos: [DailyPhoto] = []
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private var albumIdentifier: String?
    
    init() {
        loadPhotos()
        createAlbumIfNeeded()
    }
    
    var hasTodayPhoto: Bool {
        let calendar = Calendar.current
        return dailyPhotos.contains { photo in
            calendar.isDateInToday(photo.date)
        }
    }
    
    var todayPhoto: DailyPhoto? {
        let calendar = Calendar.current
        return dailyPhotos.first { photo in
            calendar.isDateInToday(photo.date)
        }
    }
    
    // 创建自定义相册
    private func createAlbumIfNeeded() {
        let albumName = "PickaPic"
        
        // 检查是否已有相册
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        
        if let album = collections.firstObject {
            albumIdentifier = album.localIdentifier
        } else {
            // 创建新相册
            var albumPlaceholder: String?
            
            PHPhotoLibrary.shared().performChanges({
                let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                albumPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection.localIdentifier
            }, completionHandler: { success, error in
                if success {
                    self.albumIdentifier = albumPlaceholder
                } else {
                    print("创建相册失败: \(error?.localizedDescription ?? "")")
                }
            })
        }
    }
    
    func addPhoto(_ image: UIImage, description: String) {
        // 如果今天已经有照片，先删除它
        if let existingPhoto = todayPhoto {
            dailyPhotos.removeAll { $0.id == existingPhoto.id }
            try? FileManager.default.removeItem(at: documentsPath.appendingPathComponent("\(existingPhoto.id).jpg"))
        }
        
        let newPhoto = DailyPhoto(
            id: UUID(),
            image: image,
            description: description,
            date: Date()
        )
        
        // 保存到相册
        saveImageToAlbum(image) { success in
            if success {
                print("照片已保存到相册")
            } else {
                print("保存照片到相册失败")
            }
        }
        
        // 保存到应用内
        dailyPhotos.append(newPhoto)
        savePhotos()
    }
    
    // 保存照片到系统相册
    private func saveImageToAlbum(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        guard let albumIdentifier = albumIdentifier else {
            completion(false)
            return
        }
        
        var assetLocalIdentifier: String?
        
        // 首先保存照片到相机胶卷
        PHPhotoLibrary.shared().performChanges({
            let createAssetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
            assetLocalIdentifier = createAssetRequest.placeholderForCreatedAsset?.localIdentifier
        }) { success, error in
            if success, let assetLocalIdentifier = assetLocalIdentifier {
                // 然后将照片添加到自定义相册
                PHPhotoLibrary.shared().performChanges({
                    guard let album = PHAssetCollection.fetchAssetCollections(
                        withLocalIdentifiers: [albumIdentifier],
                        options: nil
                    ).firstObject else { return }
                    
                    let request = PHAssetCollectionChangeRequest(for: album)
                    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetLocalIdentifier], options: nil)
                    request?.addAssets(assets as! NSFastEnumeration)
                }) { success, error in
                    if let error = error {
                        print("保存照片到相册失败: \(error.localizedDescription)")
                    }
                    completion(success)
                }
            } else {
                if let error = error {
                    print("保存照片失败: \(error.localizedDescription)")
                }
                completion(false)
            }
        }
    }
    
    private func loadPhotos() {
        // 加载照片索引
        if let data = try? Data(contentsOf: documentsPath.appendingPathComponent("photos.json")),
           let photoIndexes = try? JSONDecoder().decode([PhotoIndex].self, from: data) {
            
            // 从文件加载每张照片
            dailyPhotos = photoIndexes.compactMap { index in
                guard let imageData = try? Data(contentsOf: documentsPath.appendingPathComponent("\(index.id).jpg")),
                      let image = UIImage(data: imageData) else {
                    return nil
                }
                
                return DailyPhoto(
                    id: index.id,
                    image: image,
                    description: index.description,
                    date: index.date
                )
            }
        }
    }
    
    private func savePhotos() {
        // 保存照片索引
        let photoIndexes = dailyPhotos.map { photo in
            PhotoIndex(
                id: photo.id,
                description: photo.description,
                date: photo.date
            )
        }
        
        if let indexData = try? JSONEncoder().encode(photoIndexes) {
            try? indexData.write(to: documentsPath.appendingPathComponent("photos.json"))
        }
        
        // 保存每张照片
        for photo in dailyPhotos {
            if let imageData = photo.image.jpegData(compressionQuality: 0.8) {
                try? imageData.write(to: documentsPath.appendingPathComponent("\(photo.id).jpg"))
            }
        }
    }
    
    func getPhoto(for date: Date) -> DailyPhoto? {
        let calendar = Calendar.current
        return dailyPhotos.first { photo in
            calendar.isDate(photo.date, inSameDayAs: date)
        }
    }
}

// 用于保存到 JSON 的照片索引结构
private struct PhotoIndex: Codable {
    let id: UUID
    let description: String
    let date: Date
} 