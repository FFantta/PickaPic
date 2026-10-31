import SwiftUI

func L(_ chinese: String, _ english: String) -> String {
    let choice = UserDefaults.standard.string(forKey: "language") ?? "system"
    let zh = choice == "zh" || (choice == "system" && Locale.preferredLanguages.first?.hasPrefix("zh") == true)
    return zh ? chinese : english
}
enum Paper {
    static let background = Color(red: 0.97, green: 0.96, blue: 0.94)
    static let ink = Color(red: 0.09, green: 0.10, blue: 0.09)
    static let muted = Color(red: 0.43, green: 0.44, blue: 0.41)
    static let lime = Color(red: 0.86, green: 0.96, blue: 0.29)
    static let lilac = Color(red: 0.80, green: 0.75, blue: 0.93)
    static let sage = Color(red: 0.78, green: 0.83, blue: 0.70)
    static let line = Color.black.opacity(0.12)
}
struct RoundIcon: View {
    let symbol: String; var fill: Color = .white
    var body: some View { Image(systemName: symbol).font(.system(size: 18, weight: .medium)).frame(width: 46, height: 46).background(fill, in: Circle()).foregroundStyle(Paper.ink) }
}
struct PrimaryButton: View {
    let title: String; var symbol = "arrow.up.right"; var dark = false; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack { Text(title).font(.headline); Spacer(); Image(systemName: symbol).font(.headline) }
                .padding(.horizontal, 22).frame(minHeight: 58)
                .background(dark ? Paper.ink : Paper.lime, in: Capsule())
                .foregroundStyle(dark ? .white : Paper.ink)
        }.buttonStyle(.plain)
    }
}
struct Eyebrow: View {
    let text: String
    var body: some View { Text(text.uppercased()).font(.system(size: 11, weight: .semibold, design: .monospaced)).tracking(1.7).foregroundStyle(Paper.muted) }
}
struct PageHeading: View {
    let kicker: String; let title: String
    var body: some View { VStack(alignment: .leading, spacing: 12) { Eyebrow(text: kicker); Text(title).font(.system(size: 42, weight: .bold, design: .rounded)).tracking(-1.8).fixedSize(horizontal: false, vertical: true) }.frame(maxWidth: .infinity, alignment: .leading) }
}
struct Flower: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(); let c = CGPoint(x: rect.midX, y: rect.midY)
        for i in 0..<120 {
            let a = Double(i) / 120 * .pi * 2
            let r = min(rect.width, rect.height) * (0.36 + 0.10 * cos(a * 8))
            let v = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
            if i == 0 { p.move(to: v) } else { p.addLine(to: v) }
        }; p.closeSubpath(); return p
    }
}
struct BookArtwork: View {
    var year: Int; var title: String = "THE LITTLE\nTHINGS"; var count: Int = 0
    var coverURL: URL?
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 7).fill(Paper.ink).offset(x: 7, y: 7)
            RoundedRectangle(cornerRadius: 7).fill(Paper.lilac)
            Rectangle().fill(.black.opacity(0.1)).frame(width: 14)
            VStack(alignment: .leading, spacing: 14) {
                HStack { Text("PICKAPIC").tracking(2); Spacer(); Text("VOL. \(String(year).suffix(2))") }.font(.system(size: 9, weight: .bold, design: .monospaced))
                Spacer()
                Text(title).font(.system(size: 31, weight: .black, design: .rounded)).tracking(-1.1).lineLimit(4).minimumScaleFactor(0.6)
                if let coverURL { PhotoTile(url: coverURL, maxPixel: 900, fit: true).frame(height: 110).clipShape(RoundedRectangle(cornerRadius: 3)) }
                else { HStack { Flower().fill(Paper.lime).frame(width: 72, height: 72).overlay(Image(systemName: "sun.max").font(.title2)); Spacer() } }
                Spacer()
                HStack { Text(String(year)).font(.system(size: 34, weight: .light, design: .serif)); Spacer(); Text(L("\(count) 个日子", "\(count) DAYS")).font(.system(size: 10, weight: .medium, design: .monospaced)) }
            }.padding(24).padding(.leading, 9)
        }.aspectRatio(0.72, contentMode: .fit).foregroundStyle(Paper.ink)
    }
}
struct PhotoTile: View {
    let url: URL; var maxPixel = 900; var fit = false
    @State private var image: UIImage?
    @State private var failed = false
    var body: some View {
        GeometryReader { geo in
            Group {
                if let image { Image(uiImage: image).resizable().aspectRatio(contentMode: fit ? .fit : .fill) }
                else { ZStack { Paper.sage.opacity(0.35); VStack(spacing: 8) { Image(systemName: failed ? "exclamationmark.triangle" : "photo"); if failed && fit { Text(L("照片文件不可用，请从备份恢复。", "Photo unavailable. Restore from a backup.")).font(.caption).multilineTextAlignment(.center).padding(12) } }.foregroundStyle(Paper.muted) } }
            }.frame(width: geo.size.width, height: geo.size.height).clipped()
        }
        .task(id: url) {
            image = nil; failed = false
            let loaded = await Task.detached(priority: .userInitiated) { ImageProcessor.load(url, maxPixel: maxPixel) }.value
            if !Task.isCancelled { image = loaded; failed = loaded == nil }
        }
    }
}
extension View {
    func paperScreen() -> some View { self.background(Paper.background.ignoresSafeArea()).foregroundStyle(Paper.ink) }
}
