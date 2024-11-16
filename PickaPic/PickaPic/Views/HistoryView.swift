import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var photoManager: PhotoManager
    
    var body: some View {
        NavigationView {
            List(photoManager.dailyPhotos) { photo in
                HStack {
                    Image(uiImage: photo.image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading) {
                        Text(photo.description)
                            .lineLimit(2)
                        Text(photo.date, style: .date)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("照片记录")
        }
    }
} 