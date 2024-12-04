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
                        // 白色背景卡片
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .shadow(color: .gray.opacity(0.2), radius: 10)
                            .frame(width: UIScreen.main.bounds.width - 40, height: UIScreen.main.bounds.width - 40)
                        
                        if let image = selectedImage ?? photoManager.todayPhoto?.image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: UIScreen.main.bounds.width - 60, height: UIScreen.main.bounds.width - 60)
                                .clipShape(RoundedRectangle(cornerRadius: 15))
                        } else {
                            VStack(spacing: 15) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray.opacity(0.5))
                                Text("今天还没有拍照哦")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                            .frame(width: UIScreen.main.bounds.width - 60, height: UIScreen.main.bounds.width - 60)
                            .background(Color(red: 224/255, green: 237/255, blue: 255/255))
                            .cornerRadius(15)
                        }
                    }
                    .padding(.top, 20)
                    
                    // 描述输入区域
                    VStack(alignment: .leading, spacing: 8) {
                        Text("今日状态")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(Color(red: 100/255, green: 90/255, blue: 230/255))
                            .padding(.leading)
                        
                        TextField("写下此刻的想法...", text: $description)
                            .padding()
                            .background(Color(red: 224/255, green: 237/255, blue: 255/255))
                            .cornerRadius(8)
                            .foregroundColor(.black)
                            .focused($isTextFieldFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                isTextFieldFocused = false
                                if let image = selectedImage {
                                    photoManager.addPhoto(image, description: description)
                                    selectedImage = nil
                                }
                            }
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
                                    Text(photoManager.hasTodayPhoto ? "重新拍照" : "拍照")
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
                                    Text(photoManager.hasTodayPhoto ? "重新选择" : "相册")
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
                    }
                }
                .padding(.bottom)
            }
            .background(Color(red: 255/255, green: 242/255, blue: 223/255))
            .onTapGesture {
                isTextFieldFocused = false
            }
            .navigationTitle("Pick a Pic")
            .fullScreenCover(isPresented: $showCamera) {
                ImagePicker(image: $selectedImage, sourceType: .camera)
                    .edgesIgnoringSafeArea(.all)
                    .onDisappear {
                        if let image = selectedImage {
                            photoManager.addPhoto(image, description: description)
                            selectedImage = nil
                        }
                    }
            }
            .fullScreenCover(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
                    .edgesIgnoringSafeArea(.all)
                    .onDisappear {
                        if let image = selectedImage {
                            photoManager.addPhoto(image, description: description)
                            selectedImage = nil
                        }
                    }
            }
            .preferredColorScheme(.light)
        }
        .preferredColorScheme(.light)
        .onAppear {
            if let todayPhoto = photoManager.todayPhoto {
                description = todayPhoto.description
            }
        }
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