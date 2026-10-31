import SwiftUI
import PhotosUI
import AVFoundation
import ImageIO

struct EditorScreen: View {
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dismiss) private var dismiss
    let entry: JournalEntry?
    @State private var date: Date
    @State private var caption: String
    @State private var image: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showCrop = false
    @State private var crop: PhotoCrop?
    @State private var saveToPhotos = false
    @State private var loading = false
    @State private var saving = false
    @State private var message: String?
    @State private var conflict = false
    @State private var discard = false
    @State private var dirty = false
    @State private var suggestedDate: Date?
    init(day: Day, entry: JournalEntry?) {
        self.entry = entry
        _date = State(initialValue: day.date)
        _caption = State(initialValue: entry?.caption ?? "")
        _crop = State(initialValue: entry?.crop)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Eyebrow(text: entry == nil ? L("新的一页", "A NEW PAGE") : L("编辑这一页", "EDIT THIS PAGE"))
                    DatePicker(L("记录日期", "Page date"), selection: $date, in: ...Date(), displayedComponents: .date).font(.headline)
                    if let suggestedDate, Day(suggestedDate) != Day(date), suggestedDate <= Date() {
                        Button(L("照片拍摄于 \(Day(suggestedDate).rawValue)，使用这个日期", "Use photo date: \(Day(suggestedDate).rawValue)")) { date = suggestedDate; dirty = true }.font(.caption)
                    }
                    ZStack {
                        RoundedRectangle(cornerRadius: 24).fill(Paper.sage.opacity(0.3))
                        if let image { Image(uiImage: crop.map { ImageProcessor.crop(image, using: $0) } ?? image).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 24)) }
                        else if let entry { PhotoTile(url: store.url(for: entry), maxPixel: 2000, fit: true).clipShape(RoundedRectangle(cornerRadius: 24)) }
                        else { VStack(spacing: 12) { Image(systemName: "photo.badge.plus").font(.largeTitle); Text(L("选一张今天的照片", "A photo to remember today")).font(.subheadline) }.foregroundStyle(Paper.muted) }
                        if loading { ProgressView().padding().background(.regularMaterial, in: Circle()) }
                    }.frame(height: 300)
                    HStack(spacing: 12) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) { Label(L("选照片", "Choose photo"), systemImage: "photo").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 15).background(.white, in: Capsule()) }
                        Button { Task { await openCamera() } } label: { RoundIcon(symbol: "camera", fill: Paper.lime) }.accessibilityLabel(L("拍照", "Camera"))
                        Button { Task { if image == nil, let entry { let sourceURL = store.url(for: entry); image = await Task.detached { ImageProcessor.load(sourceURL, maxPixel: 6000) }.value }; if image != nil { showCrop = true } } } label: { RoundIcon(symbol: "crop") }.disabled(image == nil && entry == nil).accessibilityLabel(L("调整书页裁切", "Adjust book crop"))
                    }
                    HStack { Text(L("几句想说的话", "A few words")).font(.headline); Spacer(); Text("\(caption.count)/50").font(.caption.monospaced()).foregroundStyle(Paper.muted) }
                    TextField(L("这一刻，想记住什么？", "What would you like to remember?"), text: $caption, axis: .vertical).lineLimit(3...6).padding(18).background(.white, in: RoundedRectangle(cornerRadius: 18)).onChange(of: caption) { value in caption = String(value.prefix(50)); dirty = true }
                    if image != nil { Toggle(L("另存一份到系统相册", "Also save a copy to Photos"), isOn: $saveToPhotos).font(.subheadline) }
                    Text(L("照片和文字保存在本机。裁切只影响书页，完整照片仍保留。", "Saved on your device. Book cropping never removes your full photo.")).font(.caption).foregroundStyle(Paper.muted)
                    PrimaryButton(title: saving ? L("正在保存…", "Saving…") : L("保存这一页", "Keep this page"), symbol: "checkmark") { Task { await save(replace: false) } }.disabled(saving || loading || (image == nil && entry == nil))
                }.padding(24)
            }.paperScreen().navigationTitle(L("留住一个瞬间", "Keep a moment")).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("取消", "Cancel")) { if dirty { discard = true } else { dismiss() } }.disabled(saving) } }
                .interactiveDismissDisabled(dirty || saving)
                .onChange(of: date) { _ in dirty = true }
                .onChange(of: selectedPhoto) { item in
                    guard let item else { return }
                    Task {
                        loading = true; defer { loading = false }
                        do {
                            guard let data = try await item.loadTransferable(type: Data.self), let selected = UIImage(data: data) else { throw JournalError.missingImage }
                            image = selected; crop = nil; dirty = true; suggestedDate = ImageProcessor.captureDate(data)
                        } catch { message = error.localizedDescription }
                    }
                }
                .fullScreenCover(isPresented: $showCamera) { CameraPicker { result in if let result { image = result; crop = nil; dirty = true }; showCamera = false }.ignoresSafeArea() }
                .sheet(isPresented: $showCrop) { if let image { CropScreen(image: image, crop: $crop) } }
                .alert(L("请检查", "Please check"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) { Button(L("好", "OK")) { message = nil } } message: { Text(message ?? "") }
                .confirmationDialog(L("这个日期已有一页。替换后旧记录进入回收站。", "This day already has a page. Replacing moves the old page to Recently Deleted."), isPresented: $conflict, titleVisibility: .visible) { Button(L("替换旧记录", "Replace existing page"), role: .destructive) { Task { await save(replace: true) } } }
                .confirmationDialog(L("放弃还没保存的修改？", "Discard unsaved changes?"), isPresented: $discard, titleVisibility: .visible) { Button(L("放弃修改", "Discard changes"), role: .destructive) { dismiss() } }
        }
    }
    private func save(replace: Bool) async {
        saving = true; defer { saving = false }
        do { try await store.save(day: Day(date), caption: caption, image: image, editing: entry, replace: replace, saveToPhotos: saveToPhotos, crop: crop); dirty = false; dismiss() }
        catch JournalError.dayConflict { conflict = true }
        catch { message = error.localizedDescription }
    }
    private func openCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else { message = L("当前设备没有可用相机，请从相册选图。", "No camera is available. Choose a photo instead."); return }
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let allowed: Bool
        if status == .notDetermined { allowed = await AVCaptureDevice.requestAccess(for: .video) } else { allowed = status == .authorized }
        if allowed { showCamera = true } else { message = L("相机权限未开启。可在系统设置中允许，或从相册选图。", "Camera access is off. Enable it in Settings, or choose a photo.") }
    }
}
struct CameraPicker: UIViewControllerRepresentable {
    let completion: (UIImage?) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController { let c = UIImagePickerController(); c.sourceType = .camera; c.delegate = context.coordinator; return c }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (UIImage?) -> Void
        init(completion: @escaping (UIImage?) -> Void) { self.completion = completion }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { completion(nil) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) { completion(info[.originalImage] as? UIImage) }
    }
}
struct CropScreen: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    @Binding var crop: PhotoCrop?
    @State private var value = PhotoCrop()
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(uiImage: ImageProcessor.crop(image, using: value)).resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 20))
                HStack { Text(L("左右", "Horizontal")); Slider(value: $value.x, in: 0...1) }
                HStack { Text(L("上下", "Vertical")); Slider(value: $value.y, in: 0...1) }
                HStack { Text(L("放大", "Zoom")); Slider(value: $value.zoom, in: 1...3) }
                Button(L("使用完整照片", "Use full photo")) { crop = nil; dismiss() }
                PrimaryButton(title: L("使用此裁切", "Use this crop"), symbol: "checkmark") { crop = value; dismiss() }
            }.padding(24).paperScreen().navigationTitle(L("调整书页画面", "Book framing")).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("取消", "Cancel")) { dismiss() } } }
        }.onAppear { value = crop ?? PhotoCrop() }
    }
}
extension ImageProcessor {
    static func crop(_ image: UIImage, using crop: PhotoCrop) -> UIImage {
        let normalized = normalized(image)
        let size = normalized.size
        let edge = min(size.width, size.height) / CGFloat(crop.zoom)
        let rect = CGRect(x: (size.width - edge) * CGFloat(crop.x), y: (size.height - edge) * CGFloat(crop.y), width: edge, height: edge)
        guard let cg = normalized.cgImage?.cropping(to: rect) else { return normalized }
        return UIImage(cgImage: cg)
    }
    static func captureDate(_ data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), let meta = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any], let exif = meta[kCGImagePropertyExifDictionary] as? [CFString: Any], let text = exif[kCGImagePropertyExifDateTimeOriginal] as? String else { return nil }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy:MM:dd HH:mm:ss"; return f.date(from: text)
    }
}
