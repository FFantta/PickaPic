import SwiftUI

class PhotoManager: ObservableObject {
    @Published var photos: [Photo] = []
    
    private let saveKey = "SavedPhotos"
    
    init() {
        loadPhotos()
    }
    
    func addPhoto(_ photo: Photo) {
        photos.append(photo)
        savePhotos()
    }
    
    func deletePhoto(_ photo: Photo) {
        photos.removeAll { $0.id == photo.id }
        savePhotos()
    }
    
    private func savePhotos() {
        if let encoded = try? JSONEncoder().encode(photos) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func loadPhotos() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Photo].self, from: data) {
            photos = decoded
        }
    }
} 