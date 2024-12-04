import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @State private var selectedDate = Date()
    @State private var selectedPhoto: DailyPhoto?
    @State private var isShowingDetail = false
    @State private var selectedCell: UUID?
    @State private var isExporting = false
    @Namespace private var animation
    
    private let calendar = Calendar.current
    private let daysInWeek = 7
    private let gridSpacing: CGFloat = 2
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 255/255, green: 242/255, blue: 223/255)
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
                                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isShowingDetail)
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
            .navigationTitle("时光记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: exportCurrentMonthPhotos) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $isExporting) {
                ShareSheet(items: prepareExportItems())
            }
            .onDisappear {
                isShowingDetail = false
                selectedPhoto = nil
                selectedCell = nil
            }
            .preferredColorScheme(.light)
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
    
    private func prepareExportItems() -> [Any] {
        let currentMonthPhotos = photoManager.dailyPhotos.filter { photo in
            calendar.isDate(photo.date, equalTo: selectedDate, toGranularity: .month)
        }.sorted { $0.date < $1.date }
        
        var exportItems: [Any] = []
        
        // 创建一个临时目录
        let tempDir = FileManager.default.temporaryDirectory
        let exportDir = tempDir.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: exportDir, withIntermediateDirectories: true)
        
        // 保存照片和描述
        for (index, photo) in currentMonthPhotos.enumerated() {
            // 保存照片
            if let imageData = photo.image.jpegData(compressionQuality: 1.0) {
                let imageFile = exportDir.appendingPathComponent("\(index + 1).jpg")
                try? imageData.write(to: imageFile)
                exportItems.append(imageFile)
            }
            
            // 创建描述文本
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            let description = """
            日期：\(dateFormatter.string(from: photo.date))
            描述：\(photo.description)
            
            """
            
            // 将描述添加到文本文件
            if index == 0 {
                let textFile = exportDir.appendingPathComponent("描述.txt")
                try? description.write(to: textFile, atomically: true, encoding: .utf8)
                exportItems.append(textFile)
            } else {
                if let textFileURL = exportItems.last as? URL,
                   let existingText = try? String(contentsOf: textFileURL, encoding: .utf8) {
                    try? (existingText + description).write(to: textFileURL, atomically: true, encoding: .utf8)
                }
            }
        }
        
        return exportItems
    }
    
    private func exportCurrentMonthPhotos() {
        isExporting = true
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
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(2)
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
                .fill(isToday ? Color(red: 255/255, green: 179/255, blue: 179/255) : Color(red: 255/255, green: 230/255, blue: 204/255))
                .frame(width: UIScreen.main.bounds.width / 7 - 4, height: UIScreen.main.bounds.width / 7 - 4)
            
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.gray)
        }
    }
}

// 修改照片详情覆盖视图
struct PhotoDetailOverlay: View {
    let photo: DailyPhoto
    @Binding var isShowing: Bool
    let namespace: Namespace.ID
    @EnvironmentObject var photoManager: PhotoManager
    @State private var offset = CGSize.zero
    @State private var currentPhoto: DailyPhoto
    @State private var opacity: Double = 1.0
    @State private var nextPhoto: DailyPhoto?
    
    init(photo: DailyPhoto, isShowing: Binding<Bool>, namespace: Namespace.ID) {
        self.photo = photo
        self._isShowing = isShowing
        self.namespace = namespace
        self._currentPhoto = State(initialValue: photo)
    }
    
    var body: some View {
        ZStack {
            Color(red: 255/255, green: 242/255, blue: 223/255)
                .ignoresSafeArea()
            
            VStack {
                // 顶部导航栏
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isShowing = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .bold))
                            Text("返回")
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundColor(.black)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // 主要内容区域
                GeometryReader { geometry in
                    VStack {
                        Spacer()
                        
                        // 照片区域
                        ZStack {
                            // 当前照片
                            Image(uiImage: currentPhoto.image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: geometry.size.width - 32)
                                .cornerRadius(15)
                                .opacity(opacity)
                                .padding(.horizontal, 16)
                            
                            // 下一张照片
                            if let next = nextPhoto {
                                Image(uiImage: next.image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: geometry.size.width - 32)
                                    .cornerRadius(15)
                                    .padding(.horizontal, 16)
                                    .offset(x: offset.width < 0 ? geometry.size.width : -geometry.size.width)
                                    .offset(x: offset.width)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = value.translation
                                    // 根据滑动方向预加载下一张照片
                                    if value.translation.width > 0 {
                                        nextPhoto = getPreviousPhoto()
                                    } else if value.translation.width < 0 {
                                        nextPhoto = getNextPhoto()
                                    }
                                    // 调整当前照片的透明度
                                    let progress = abs(value.translation.width) / 200.0
                                    opacity = 1.0 - min(progress, 1.0)
                                }
                                .onEnded { value in
                                    let threshold: CGFloat = 50
                                    
                                    if abs(value.translation.width) > threshold {
                                        if value.translation.width > 0 {
                                            // 向右滑动，显示前一天
                                            if let previousPhoto = getPreviousPhoto() {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    offset.width = geometry.size.width
                                                    opacity = 0
                                                }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                                    currentPhoto = previousPhoto
                                                    offset = .zero
                                                    opacity = 1
                                                    nextPhoto = nil
                                                }
                                            } else {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    offset = .zero
                                                    opacity = 1
                                                }
                                            }
                                        } else {
                                            // 向左滑动，显示后一天
                                            if let nextPhoto = getNextPhoto() {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    offset.width = -geometry.size.width
                                                    opacity = 0
                                                }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                                    currentPhoto = nextPhoto
                                                    offset = .zero
                                                    opacity = 1
                                                    self.nextPhoto = nil
                                                }
                                            } else {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    offset = .zero
                                                    opacity = 1
                                                }
                                            }
                                        }
                                    } else {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            offset = .zero
                                            opacity = 1
                                            nextPhoto = nil
                                        }
                                    }
                                }
                        )
                        
                        Spacer()
                        
                        // 描述和日期
                        VStack(spacing: 16) {
                            if !currentPhoto.description.isEmpty {
                                Text(currentPhoto.description)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            
                            Text(currentPhoto.date.formatted(date: .complete, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 30)
                    }
                }
            }
        }
    }
    
    // 获取前一天的照片
    private func getPreviousPhoto() -> DailyPhoto? {
        let sortedPhotos = photoManager.dailyPhotos.sorted { $0.date > $1.date }
        if let index = sortedPhotos.firstIndex(where: { $0.id == currentPhoto.id }),
           index < sortedPhotos.count - 1 {
            return sortedPhotos[index + 1]
        }
        return nil
    }
    
    // 获取后一天的照片
    private func getNextPhoto() -> DailyPhoto? {
        let sortedPhotos = photoManager.dailyPhotos.sorted { $0.date > $1.date }
        if let index = sortedPhotos.firstIndex(where: { $0.id == currentPhoto.id }),
           index > 0 {
            return sortedPhotos[index - 1]
        }
        return nil
    }
}

// 添加分享sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
} 