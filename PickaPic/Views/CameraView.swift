import SwiftUI
import PhotosUI

struct CameraView: View {
    @EnvironmentObject var photoManager: PhotoManager
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var inputImage: UIImage?
    @State private var description = ""
    @State private var selectedCategory: PhotoCategory = .other
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let inputImage = inputImage {
                    Image(uiImage: inputImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 300)
                } else {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 300)
                        .foregroundColor(.gray)
                }
                
                Picker("类别", selection: $selectedCategory) {
                    ForEach(PhotoCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                
                TextField("添加描述...", text: $description)
                    .textFieldStyle(.roundedBorder)
                
                HStack(spacing: 20) {
                    Button(action: { showCamera = true }) {
                        Label("拍照", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: { showImagePicker = true }) {
                        Label("相册", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                
                if inputImage != nil {
                    Button("保存") {
                        savePhoto()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("每日一拍")
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $inputImage)
            }
            .sheet(isPresented: $showCamera) {
                CameraPickerView(image: $inputImage)
            }
        }
    }
    
    private func savePhoto() {
        guard let inputImage = inputImage,
              let imageData = inputImage.jpegData(compressionQuality: 0.8) else { return }
        
        let photo = Photo(
            imageData: imageData,
            description: description,
            category: selectedCategory
        )
        
        photoManager.addPhoto(photo)
        self.inputImage = nil
        self.description = ""
        self.selectedCategory = .other
    }
} 