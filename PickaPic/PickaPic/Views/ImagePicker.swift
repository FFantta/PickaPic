import SwiftUI
import Photos
import AVFoundation

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        
        // 基本设置
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.modalPresentationStyle = .fullScreen
        
        // 相机特定设置
        if sourceType == .camera {
            // 确保设备支持相机
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                print("相机不可用")
                return picker
            }
            
            picker.cameraCaptureMode = .photo
            picker.cameraDevice = .rear
            picker.showsCameraControls = true
            picker.navigationBar.isHidden = true
            picker.toolbar.isHidden = true
            
            if let cameraViewController = picker.viewControllers.first {
                cameraViewController.view.backgroundColor = .black
                cameraViewController.edgesForExtendedLayout = .all
            }
        }
        
        // 权限检查
        if sourceType == .photoLibrary {
            checkPhotoLibraryPermission()
        } else if sourceType == .camera {
            checkCameraPermission()
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus()
        if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization { _ in }
        }
    }
    
    private func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { _ in }
        }
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
} 