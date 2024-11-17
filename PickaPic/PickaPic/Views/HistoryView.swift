import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @State private var selectedDate = Date()
    @State private var selectedPhoto: DailyPhoto?
    @State private var isShowingDetail = false
    @State private var selectedCell: UUID?
    @Namespace private var animation
    
    private let calendar = Calendar.current
    private let daysInWeek = 7
    private let gridSpacing: CGFloat = 2
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 月份选择器
                    HStack(spacing: 20) {
                        Button(action: previousMonth) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        
                        Text(monthYearString(from: selectedDate))
                            .font(.system(size: 22, weight: .bold))
                            .frame(width: 150)
                            .animation(.none)
                        
                        Button(action: nextMonth) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.top, 10)
                    
                    // 星期标题
                    HStack {
                        ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { day in
                            Text(day)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                    
                    // 日历网格
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: daysInWeek), spacing: gridSpacing) {
                        ForEach(daysInMonth(), id: \.self) { date in
                            if let date = date {
                                if let photo = photoManager.getPhoto(for: date) {
                                    DayCell(date: date, photo: photo, isSelected: selectedCell == photo.id)
                                        .id(photo.id)
                                        .matchedGeometryEffect(id: photo.id, in: animation, isSource: !isShowingDetail)
                                        .onTapGesture {
                                            selectedCell = photo.id
                                            selectedPhoto = photo
                                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                                isShowingDetail = true
                                            }
                                        }
                                } else {
                                    EmptyDayCell(date: date, isToday: calendar.isDateInToday(date))
                                }
                            } else {
                                Color.clear
                                    .frame(width: UIScreen.main.bounds.width / 7 - 4, height: UIScreen.main.bounds.width / 7 - 4)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                    
                    Spacer()
                }
                
                // 照片详情覆盖层
                if isShowingDetail {
                    if let photo = selectedPhoto {
                        PhotoDetailOverlay(photo: photo, isShowing: $isShowingDetail, namespace: animation)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)),
                                removal: .opacity.combined(with: .scale(scale: 0.95))
                            ))
                            .zIndex(2)
                    }
                }
            }
            .navigationTitle("照片记录")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                isShowingDetail = false
                selectedPhoto = nil
                selectedCell = nil
            }
        }
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月"
        return formatter.string(from: date)
    }
    
    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    private func daysInMonth() -> [Date?] {
        let range = calendar.range(of: .day, in: .month, for: selectedDate)!
        let numDays = range.count
        
        let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate))!
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        
        for day in 1...numDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        
        // 补全最后一周
        let remainingCells = (daysInWeek - (days.count % daysInWeek)) % daysInWeek
        days += Array(repeating: nil as Date?, count: remainingCells)
        
        return days
    }
}

// 日期单元格视图
struct DayCell: View {
    let date: Date
    let photo: DailyPhoto
    let isSelected: Bool
    private let calendar = Calendar.current
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: photo.image)
                .resizable()
                .scaledToFill()
                .frame(width: UIScreen.main.bounds.width / 7 - 4, height: UIScreen.main.bounds.width / 7 - 4)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            // 日期标签
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .padding(2)
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .padding(2)
        }
        .scaleEffect(isSelected ? 0.95 : 1)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

struct EmptyDayCell: View {
    let date: Date
    let isToday: Bool
    private let calendar = Calendar.current
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(isToday ? Color.blue.opacity(0.1) : Color(uiColor: .secondarySystemBackground))
                .frame(width: UIScreen.main.bounds.width / 7 - 4, height: UIScreen.main.bounds.width / 7 - 4)
            
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 12, weight: isToday ? .bold : .regular))
                .foregroundColor(isToday ? .blue : .secondary)
        }
    }
}

// 修改照片详情覆盖视图
struct PhotoDetailOverlay: View {
    let photo: DailyPhoto
    @Binding var isShowing: Bool
    let namespace: Namespace.ID
    
    var body: some View {
        ZStack {
            // 背景
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // 顶部导航栏
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isShowing = false
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.black)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                // 照片
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .cornerRadius(12)
                    .padding(.horizontal)
                
                // 描述和日期
                VStack(alignment: .leading, spacing: 12) {
                    if !photo.description.isEmpty {
                        Text(photo.description)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    
                    Text(photo.date.formatted(date: .complete, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 44)
        }
    }
} 