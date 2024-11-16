import SwiftUI

class PhotoManager: ObservableObject {
    @Published var dailyPhotos: [DailyPhoto] = []
    
    init() {
        // 从本地加载保存的照片
        loadPhotos()
    }
    
    func addPhoto(_ image: UIImage, description: String) {
        let newPhoto = DailyPhoto(
            id: UUID(),
            image: image,
            description: description,
            date: Date()
        )
        dailyPhotos.append(newPhoto)
        savePhotos()
    }
    
    private func loadPhotos() {
        // TODO: 从本地存储加载照片
    }
    
    private func savePhotos() {
        // TODO: 保存照片到本地存储
    }
} 