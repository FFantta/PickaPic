import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @State private var selectedDate = Date()
    @State private var selectedPhoto: Photo?
    
    let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 月份选择器
                    MonthPickerView(selectedDate: $selectedDate)
                    
                    // 星期标题
                    WeekdayHeaderView()
                    
                    // 日历网格
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(daysInMonth(for: selectedDate), id: \.self) { date in
                            DayCellView(date: date, photo: photoFor(date: date))
                                .onTapGesture {
                                    if let photo = photoFor(date: date) {
                                        selectedPhoto = photo
                                    }
                                }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("照片日历")
            .sheet(item: $selectedPhoto) { photo in
                PhotoDetailView(photo: photo)
            }
        }
    }
    
    private func photoFor(date: Date) -> Photo? {
        photoManager.photos.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
} 