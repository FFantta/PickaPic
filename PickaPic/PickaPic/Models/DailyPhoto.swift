import SwiftUI

struct DailyPhoto: Identifiable {
    let id: UUID
    let image: UIImage
    let description: String
    let date: Date
} 