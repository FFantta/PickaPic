import SwiftUI

struct TodayView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var selectedImage: UIImage?
    @State private var description = ""
    @State private var isOverLimit = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var isKeyboardVisible = false
    @State private var keyboardHeight: CGFloat = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 255/255, green: 242/255, blue: 223/255)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    // 标题
                    HStack {
                        Text(isKeyboardVisible ? "" : "Pick a Pic")
                            .font(.system(size: 38, weight: .bold))
                            .padding(.leading, 20)
                        Spacer()
                    }
                    .padding(.top, -15)
                    .padding(.bottom, -5)
                    
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
                    .padding(.top, isKeyboardVisible ? keyboardHeight * 0.3 : 0)
                    
                    // 描述输入区域
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("今日状态")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                            Spacer()
                            if isKeyboardVisible {
                                Text("\(description.count)/50")
                                    .font(.caption)
                                    .foregroundColor(description.count > 50 ? .red : .gray)
                            }
                        }
                        .padding(.leading)
                        .padding(.trailing)
                        .padding(.bottom, 6)
                        
                        TextField("写下此刻的想法...", text: $description)
                            .padding()
                            .background(Color(red: 224/255, green: 237/255, blue: 255/255))
                            .cornerRadius(8)
                            .foregroundColor(.black)
                            .focused($isTextFieldFocused)
                            .submitLabel(.done)
                            .onChange(of: description) { newValue in
                                if newValue.count > 50 {
                                    description = String(newValue.prefix(50))
                                }
                            }
                            .onSubmit {
                                isTextFieldFocused = false
                                if let todayPhoto = photoManager.todayPhoto {
                                    photoManager.updateDescription(for: todayPhoto, with: description)
                                }
                            }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, -30)
                    
                    // 按钮区域
                    VStack(spacing: 15) {
                        HStack(spacing: 15) {
                            // 拍照按钮
                            Button(action: {
                                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                    showCamera = true
                                }
                            }) {
                                Image(photoManager.todayPhoto == nil ? "photo_4" : "rephoto_4")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 155, height: 155)
                            }
                            
                            // 相册按钮
                            Button(action: { 
                                showImagePicker = true 
                            }) {
                                Image(photoManager.todayPhoto == nil ? "upload_4" : "reupload_4")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 155, height: 155)
                            }
                            .frame(width: UIScreen.main.bounds.width * 0.4)
                            .padding(.vertical, -15)
                        }
                        .padding(.horizontal)
                    }
                }
                .onTapGesture {
                    isTextFieldFocused = false
                }
                .fullScreenCover(isPresented: $showCamera) {
                    ImagePicker(image: $selectedImage, sourceType: .camera)
                        .edgesIgnoringSafeArea(.all)
                        .onDisappear {
                            if let image = selectedImage {
                                photoManager.addPhoto(image, description: description, saveToAlbum: true)
                            }
                        }
                }
                .fullScreenCover(isPresented: $showImagePicker) {
                    ImagePicker(image: $selectedImage, sourceType: .photoLibrary)
                        .edgesIgnoringSafeArea(.all)
                        .onDisappear {
                            if let image = selectedImage {
                                photoManager.addPhoto(image, description: description, saveToAlbum: false)
                            }
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
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
                isKeyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
            isKeyboardVisible = false
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