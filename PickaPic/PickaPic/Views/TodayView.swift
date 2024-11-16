import SwiftUI

struct TodayView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var selectedImage: UIImage?
    @State private var description = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 25) {
                    // 照片显示区域
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(uiColor: .systemGray6))
                            .frame(height: 400)
                            .shadow(color: .gray.opacity(0.2), radius: 10, x: 0, y: 5)
                        
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 400)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        } else {
                            VStack(spacing: 15) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray.opacity(0.5))
                                Text("今天还没有拍照哦")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // 描述输入区域
                    VStack(alignment: .leading, spacing: 8) {
                        Text("今日心情")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.leading)
                        
                        TextField("写下此刻的想法...", text: $description)
                            .padding()
                            .background(Color(uiColor: .systemGray6))
                            .cornerRadius(15)
                            .focused($isTextFieldFocused)
                    }
                    .padding(.horizontal)
                    
                    // 按钮区域
                    VStack(spacing: 15) {
                        HStack(spacing: 15) {
                            // 拍照按钮
                            Button(action: {
                                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                    showCamera = true
                                }
                            }) {
                                HStack {
                                    Image(systemName: "camera.fill")
                                        .font(.headline)
                                    Text("拍照")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(15)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                            }
                            
                            // 相册按钮
                            Button(action: { showImagePicker = true }) {
                                HStack {
                                    Image(systemName: "photo.fill")
                                        .font(.headline)
                                    Text("相册")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(Color.purple.opacity(0.1))
                                .foregroundColor(.purple)
                                .cornerRadius(15)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                        // 保存按钮
                        if selectedImage != nil {
                            Button(action: savePhoto) {
                                HStack {
                                    Image(systemName: "square.and.arrow.down.fill")
                                        .font(.headline)
                                    Text("保存今日照片")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.blue, .purple]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(15)
                            }
                            .padding(.horizontal)
                            .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(uiColor: .systemBackground))
            .onTapGesture {
                isTextFieldFocused = false
            }
            .navigationTitle("今日一拍")
            .fullScreenCover(isPresented: $showCamera) {
                ImagePicker(image: $selectedImage, sourceType: .camera)
                    .edgesIgnoringSafeArea(.all)
            }
            .fullScreenCover(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
                    .edgesIgnoringSafeArea(.all)
            }
        }
    }
    
    private func savePhoto() {
        guard let image = selectedImage else { return }
        photoManager.addPhoto(image, description: description)
        selectedImage = nil
        description = ""
    }
}

// 扩展 Color 以支持十六进制颜色
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// 扩展 View 以支持导航栏标题颜色
extension View {
    func navigationBarTitleTextColor(_ color: Color) -> some View {
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor(color)]
        return self
    }
} 