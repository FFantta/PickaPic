import SwiftUI

enum MoodType: String, CaseIterable, Codable {
    case happy = "开心"
    case peaceful = "平静"
    case sad = "难过"
    case excited = "兴奋"
    case tired = "疲惫"
    
    var color: Color {
        switch self {
        case .happy: return Color.yellow.opacity(0.3)
        case .peaceful: return Color.blue.opacity(0.3)
        case .sad: return Color.gray.opacity(0.3)
        case .excited: return Color.pink.opacity(0.3)
        case .tired: return Color.purple.opacity(0.3)
        }
    }
    
    var icon: String {
        switch self {
        case .happy: return "😊"
        case .peaceful: return "😌"
        case .sad: return "😢"
        case .excited: return "🥳"
        case .tired: return "😴"
        }
    }
} 