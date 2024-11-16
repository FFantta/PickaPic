import SwiftUI

struct Photo: Identifiable, Codable {
    let id: UUID
    var imageData: Data
    var description: String
    var date: Date
    var category: PhotoCategory
    var location: String?
    var tags: [String]
    
    init(id: UUID = UUID(), imageData: Data, description: String = "", date: Date = Date(), category: PhotoCategory = .other, location: String? = nil, tags: [String] = []) {
        self.id = id
        self.imageData = imageData
        self.description = description
        self.date = date
        self.category = category
        self.location = location
        self.tags = tags
    }
}

enum PhotoCategory: String, Codable, CaseIterable {
    case landscape = "风景"
    case food = "美食"
    case selfie = "自拍"
    case other = "其他"
    
    var color: Color {
        switch self {
        case .landscape: return .blue
        case .food: return .orange
        case .selfie: return .pink
        case .other: return .gray
        }
    }
} 