import Foundation

/// Calendar days are values, not midnight timestamps. Travel cannot move a page.
struct Day: RawRepresentable, Codable, Hashable, Comparable, Identifiable, Sendable {
    let rawValue: String
    var id: String { rawValue }
    init?(rawValue: String) {
        let parts = rawValue.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, rawValue.count == 10 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              calendar.component(.year, from: date) == parts[0],
              calendar.component(.month, from: date) == parts[1],
              calendar.component(.day, from: date) == parts[2],
              String(format: "%04d-%02d-%02d", parts[0], parts[1], parts[2]) == rawValue else { return nil }
        self.rawValue = rawValue
    }
    init(_ date: Date, calendar: Calendar = .current) {
        rawValue = String(format: "%04d-%02d-%02d", calendar.component(.year, from: date), calendar.component(.month, from: date), calendar.component(.day, from: date))
    }
    var date: Date {
        let p = rawValue.split(separator: "-").compactMap { Int($0) }
        return Calendar.current.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: 12))!
    }
    var year: Int { Int(rawValue.prefix(4))! }
    static func < (lhs: Day, rhs: Day) -> Bool { lhs.rawValue < rhs.rawValue }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer(); let value = try c.decode(String.self)
        guard let day = Day(rawValue: value) else { throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid calendar day") }
        self = day
    }
    func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(rawValue) }
}

struct PhotoCrop: Codable, Equatable, Sendable { var x: Double = 0.5; var y: Double = 0.5; var zoom: Double = 1 }

struct JournalEntry: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var day: Day
    var caption: String
    var imageName: String
    var thumbnailName: String
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var excludedFromBook = false
    var crop: PhotoCrop?
    var isDeleted: Bool { deletedAt != nil }
}
struct JournalSnapshot: Codable, Sendable {
    var formatVersion = 2
    var entries: [JournalEntry] = []
    var importedKeys: [String]?
    func validate() throws {
        guard formatVersion == 2 else { throw JournalError.unsupportedBackup }
        guard Set(entries.map(\.id)).count == entries.count else { throw JournalError.invalidBackup }
        let live = entries.filter { !$0.isDeleted }
        guard Set(live.map(\.day)).count == live.count else { throw JournalError.dayConflict }
        for e in entries {
            if let crop = e.crop { guard crop.x.isFinite, crop.y.isFinite, crop.zoom.isFinite, (0...1).contains(crop.x), (0...1).contains(crop.y), (1...3).contains(crop.zoom) else { throw JournalError.invalidBackup } }
            guard e.caption.count <= 50,
                  UUID(uuidString: String(e.imageName.dropLast(4))) != nil,
                  e.imageName.hasSuffix(".jpg"),
                  e.thumbnailName == "thumb-" + e.imageName else { throw JournalError.invalidBackup }
        }
    }
}
enum JournalError: Error, LocalizedError {
    case dayConflict, futureDate, missingImage, invalidBackup, unsupportedBackup, noEntries, storageUnavailable
    var errorDescription: String? {
        switch self {
        case .dayConflict: return "这个日期已有记录。请选择保留现有记录或替换。 / A page already exists for this day."
        case .futureDate: return "暂时不能记录未来的日期。 / Choose today or an earlier day."
        case .missingImage: return "照片文件缺失，操作已停止，原记录未删除。 / A photo is missing. Your existing journal is unchanged."
        case .invalidBackup: return "文件校验失败，未覆盖现有数据。 / Invalid backup. Nothing was replaced."
        case .unsupportedBackup: return "备份版本不受支持，请使用兼容版本。 / Unsupported backup version."
        case .noEntries: return "所选范围没有可用记录。 / There are no pages in this range."
        case .storageUnavailable: return "存储尚未准备好，请先解决恢复提示。 / Resolve the storage recovery notice first."
        }
    }
}
enum ImportPolicy: String, CaseIterable, Sendable { case keepExisting, replaceExisting }
struct ImportSummary: Sendable { var added: Int; var conflicts: Int; var deleted: Int }

/// Immutable image blobs + one atomically replaced index: old content survives failed saves.
actor JournalRepository {
    let root: URL
    private let fm = FileManager.default
    private var snapshot = JournalSnapshot()
    private var ready = false
    var index: URL { root.appendingPathComponent("journal-v2.json") }
    var images: URL { root.appendingPathComponent("Images", isDirectory: true) }
    init(root: URL) { self.root = root }
    func open() throws -> (JournalSnapshot, String?) {
        try fm.createDirectory(at: images, withIntermediateDirectories: true)
        var notice: String?
        if fm.fileExists(atPath: index.path) {
            do { snapshot = try decode(index) }
            catch {
                let previous = root.appendingPathComponent("journal-previous.json")
                guard let recovered = try? decode(previous) else { throw error }
                let damaged = root.appendingPathComponent("damaged-\(UUID().uuidString).json")
                try fm.copyItem(at: index, to: damaged)
                try JSONEncoder().encode(recovered).write(to: index, options: .atomic)
                snapshot = recovered
                notice = "已恢复上一份索引。受损文件已保留；请检查最近一次修改并导出备份。 / Recovered the previous index. Check your latest edit and make a backup."
            }
        } else { snapshot = try migrateLegacy() }
        ready = true
        return (snapshot, notice)
    }
    private func decode(_ url: URL) throws -> JournalSnapshot {
        let value = try JSONDecoder().decode(JournalSnapshot.self, from: Data(contentsOf: url))
        try value.validate(); return value
    }
    private func commit(_ next: JournalSnapshot) throws -> JournalSnapshot {
        guard ready else { throw JournalError.storageUnavailable }
        try next.validate()
        let data = try JSONEncoder().encode(next)
        if fm.fileExists(atPath: index.path) {
            try Data(contentsOf: index).write(to: root.appendingPathComponent("journal-previous.json"), options: .atomic)
        }
        try data.write(to: index, options: .atomic)
        snapshot = next
        return next
    }
    private func migrateLegacy() throws -> JournalSnapshot {
        struct Old: Codable { let id: UUID; let description: String; let date: Date }
        let url = root.appendingPathComponent("photos.json")
        guard fm.fileExists(atPath: url.path) else { return JournalSnapshot() }
        let old = try JSONDecoder().decode([Old].self, from: Data(contentsOf: url))
        var result = JournalSnapshot(); var days = Set<Day>()
        for e in old.sorted(by: { $0.date > $1.date }) {
            let day = Day(e.date); guard days.insert(day).inserted else { continue }
            let name = "\(e.id.uuidString).jpg"
            let source = root.appendingPathComponent(name)
            guard fm.fileExists(atPath: source.path) else { throw JournalError.missingImage }
            let dest = images.appendingPathComponent(name)
            if !fm.fileExists(atPath: dest.path) { try fm.copyItem(at: source, to: dest) }
            // Legacy files remain intact. Real thumbnails are regenerated lazily by the app.
            let thumb = images.appendingPathComponent("thumb-" + name)
            if !fm.fileExists(atPath: thumb.path) { try fm.copyItem(at: source, to: thumb) }
            result.entries.append(JournalEntry(id: e.id, day: day, caption: String(e.description.prefix(50)), imageName: name, thumbnailName: "thumb-" + name, createdAt: e.date, updatedAt: e.date))
        }
        try result.validate()
        try JSONEncoder().encode(result).write(to: index, options: .atomic)
        return result
    }
    func save(day: Day, caption: String, image: Data?, thumbnail: Data?, editingID: UUID? = nil, replace: Bool = false, crop: PhotoCrop? = nil, now: Date = Date()) throws -> JournalSnapshot {
        guard ready else { throw JournalError.storageUnavailable }
        guard day <= Day(now) else { throw JournalError.futureDate }
        var next = snapshot
        let collision = next.entries.firstIndex { !$0.isDeleted && $0.day == day && $0.id != editingID }
        if collision != nil && !replace { throw JournalError.dayConflict }
        var entry = next.entries.first(where: { $0.id == editingID }) ?? JournalEntry(id: UUID(), day: day, caption: "", imageName: "", thumbnailName: "", createdAt: now, updatedAt: now)
        if let image, let thumbnail {
            let name = "\(UUID().uuidString).jpg"
            try image.write(to: images.appendingPathComponent(name), options: .atomic)
            try thumbnail.write(to: images.appendingPathComponent("thumb-" + name), options: .atomic)
            entry.imageName = name; entry.thumbnailName = "thumb-" + name
        }
        guard fm.fileExists(atPath: images.appendingPathComponent(entry.imageName).path), !entry.imageName.isEmpty else { throw JournalError.missingImage }
        if let collision { next.entries[collision].deletedAt = now }
        entry.crop = crop
        entry.day = day; entry.caption = String(caption.prefix(50)); entry.updatedAt = now; entry.deletedAt = nil
        if let i = next.entries.firstIndex(where: { $0.id == entry.id }) { next.entries[i] = entry } else { next.entries.append(entry) }
        return try commit(next)
    }
    func setDeleted(_ id: UUID, deleted: Bool, replace: Bool = false, now: Date = Date()) throws -> JournalSnapshot {
        var next = snapshot
        guard let i = next.entries.firstIndex(where: { $0.id == id }) else { return snapshot }
        if !deleted, let collision = next.entries.firstIndex(where: { $0.id != id && !$0.isDeleted && $0.day == next.entries[i].day }) {
            guard replace else { throw JournalError.dayConflict }
            next.entries[collision].deletedAt = now
        }
        next.entries[i].deletedAt = deleted ? now : nil; next.entries[i].updatedAt = now
        return try commit(next)
    }
    func exclude(_ id: UUID, value: Bool) throws -> JournalSnapshot {
        var next = snapshot
        if let i = next.entries.firstIndex(where: { $0.id == id }) { next.entries[i].excludedFromBook = value }
        return try commit(next)
    }
    func purge(ids: Set<UUID>) throws -> JournalSnapshot {
        guard !ids.isEmpty else { return snapshot }
        let removed = snapshot.entries.filter { ids.contains($0.id) }
        var next = snapshot; next.entries.removeAll { ids.contains($0.id) }
        let result = try commit(next)
        // Remove deleted content from the recovery generation before deleting its blobs.
        try JSONEncoder().encode(next).write(to: root.appendingPathComponent("journal-previous.json"), options: .atomic)
        let used = Set(next.entries.flatMap { [$0.imageName, $0.thumbnailName] })
        for name in Set(removed.flatMap { [$0.imageName, $0.thumbnailName] }) where !used.contains(name) {
            let file = images.appendingPathComponent(name)
            if fm.fileExists(atPath: file.path) { try fm.removeItem(at: file) }
        }
        let legacy = root.appendingPathComponent("photos.json")
        if let data = try? Data(contentsOf: legacy), let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            let remaining = rows.filter { row in guard let text = row["id"] as? String, let id = UUID(uuidString: text) else { return false }; return !ids.contains(id) }
            try JSONSerialization.data(withJSONObject: remaining).write(to: legacy, options: .atomic)
            for e in removed { let old = root.appendingPathComponent("\(e.id).jpg"); if fm.fileExists(atPath: old.path) { try fm.removeItem(at: old) } }
        }
        return result
    }
    func expireTrash(now: Date = Date()) throws -> JournalSnapshot {
        let cutoff = now.addingTimeInterval(-30 * 86400)
        return try purge(ids: Set(snapshot.entries.filter { ($0.deletedAt ?? .distantFuture) <= cutoff }.map(\.id)))
    }
    func usage() -> Int64 {
        let urls = (try? fm.contentsOfDirectory(at: images, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return urls.reduce(0) { $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }
    func cleanOrphans() throws -> JournalSnapshot {
        // Keep the previous committed generation usable as well.
        let previous = try? decode(root.appendingPathComponent("journal-previous.json"))
        let entries = snapshot.entries + (previous?.entries ?? [])
        let used = Set(entries.flatMap { [$0.imageName, $0.thumbnailName] })
        for file in try fm.contentsOfDirectory(at: images, includingPropertiesForKeys: nil) where !used.contains(file.lastPathComponent) {
            try fm.removeItem(at: file)
        }
        return snapshot
    }
    func makeBackup(recovery: Bool = false) throws -> URL {
        guard ready else { throw JournalError.storageUnavailable }
        let base = recovery ? root.appendingPathComponent("Recovery", isDirectory: true) : fm.temporaryDirectory
        try fm.createDirectory(at: base, withIntermediateDirectories: true)
        let folder = base.appendingPathComponent("PickaPic-\(UUID().uuidString).pickapic", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            let blobs = folder.appendingPathComponent("Images", isDirectory: true)
            try fm.createDirectory(at: blobs, withIntermediateDirectories: true)
            for name in Set(snapshot.entries.flatMap { [$0.imageName, $0.thumbnailName] }) {
                let source = images.appendingPathComponent(name)
                guard fm.fileExists(atPath: source.path) else { throw JournalError.missingImage }
                try fm.copyItem(at: source, to: blobs.appendingPathComponent(name))
            }
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: folder.appendingPathComponent("manifest.json"), options: .atomic)
            var checksums: [String: String] = [:]
            for name in Set(snapshot.entries.flatMap { [$0.imageName, $0.thumbnailName] }) { checksums["Images/" + name] = try checksum(folder.appendingPathComponent("Images/" + name)) }
            checksums["manifest.json"] = try checksum(folder.appendingPathComponent("manifest.json"))
            try JSONEncoder().encode(checksums).write(to: folder.appendingPathComponent("checksums.json"), options: .atomic)
            return folder
        } catch { try? fm.removeItem(at: folder); throw error }
    }
    func inspectBackup(_ folder: URL) throws -> ImportSummary {
        let imported = try validatedBackup(folder)
        let currentDays = Set(snapshot.entries.filter { !$0.isDeleted }.map(\.day))
        let live = imported.entries.filter { !$0.isDeleted }
        return ImportSummary(added: live.filter { !currentDays.contains($0.day) }.count, conflicts: live.filter { currentDays.contains($0.day) }.count, deleted: imported.entries.filter(\.isDeleted).count)
    }
    private func validatedBackup(_ folder: URL) throws -> JournalSnapshot {
        let info = try folder.appendingPathComponent("Images").resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        guard info.isSymbolicLink != true, info.isDirectory == true else { throw JournalError.invalidBackup }
        let sums = try JSONDecoder().decode([String: String].self, from: Data(contentsOf: folder.appendingPathComponent("checksums.json")))
        guard sums["manifest.json"] == (try checksum(folder.appendingPathComponent("manifest.json"))) else { throw JournalError.invalidBackup }
        let data = try Data(contentsOf: folder.appendingPathComponent("manifest.json"))
        let value = try JSONDecoder().decode(JournalSnapshot.self, from: data); try value.validate()
        for name in Set(value.entries.flatMap { [$0.imageName, $0.thumbnailName] }) {
            let url = folder.appendingPathComponent("Images").appendingPathComponent(name)
            let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey])
            guard values.isSymbolicLink != true, values.isRegularFile == true, (values.fileSize ?? 0) > 0, sums["Images/" + name] == (try checksum(url)) else { throw JournalError.invalidBackup }
        }
        return value
    }
    func restore(_ folder: URL, policy: ImportPolicy) throws -> JournalSnapshot {
        let imported = try validatedBackup(folder)
        if ready { _ = try makeBackup(recovery: true) }
        else {
            // Explicit restore is allowed even when both indexes are unreadable.
            let archive = root.appendingPathComponent("Recovery", isDirectory: true)
            try fm.createDirectory(at: archive, withIntermediateDirectories: true)
            if fm.fileExists(atPath: index.path) { try fm.copyItem(at: index, to: archive.appendingPathComponent("damaged-\(UUID()).json")) }
            snapshot = JournalSnapshot(); ready = true
        }
        var next = snapshot
        for incoming in imported.entries {
            let key = "\(incoming.id)|\(incoming.imageName)|\(incoming.updatedAt.timeIntervalSinceReferenceDate)|\(incoming.deletedAt?.timeIntervalSinceReferenceDate ?? -1)"
            if next.importedKeys?.contains(key) == true { continue }
            if next.entries.contains(where: { $0.id == incoming.id && $0 == incoming }) { continue }
            if !incoming.isDeleted, let i = next.entries.firstIndex(where: { !$0.isDeleted && $0.day == incoming.day }) {
                if policy == .keepExisting { continue }
                next.entries[i].deletedAt = Date()
            }
            var entry = incoming
            if next.entries.contains(where: { $0.id == entry.id }) { entry.id = UUID() }
            let newName = "\(UUID().uuidString).jpg"
            try fm.copyItem(at: folder.appendingPathComponent("Images/" + incoming.imageName), to: images.appendingPathComponent(newName))
            try fm.copyItem(at: folder.appendingPathComponent("Images/" + incoming.thumbnailName), to: images.appendingPathComponent("thumb-" + newName))
            entry.imageName = newName; entry.thumbnailName = "thumb-" + newName
            next.entries.append(entry)
            next.importedKeys = (next.importedKeys ?? []) + [key]
        }
        return try commit(next)
    }
    func recoveryBackups() throws -> [URL] {
        let folder = root.appendingPathComponent("Recovery", isDirectory: true)
        guard fm.fileExists(atPath: folder.path) else { return [] }
        return try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey]).filter { $0.pathExtension == "pickapic" }.sorted { ((try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast) > ((try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast) }
    }
    func restoreRecovery(_ folder: URL) throws -> JournalSnapshot {
        let allowed = try recoveryBackups()
        guard allowed.contains(where: { $0.resolvingSymlinksInPath().standardizedFileURL.path == folder.resolvingSymlinksInPath().standardizedFileURL.path }) else { throw JournalError.invalidBackup }
        let recovered = try validatedBackup(folder)
        _ = try makeBackup(recovery: true)
        var next = recovered
        for i in next.entries.indices {
            let e = next.entries[i]; let name = "\(UUID()).jpg"
            try fm.copyItem(at: folder.appendingPathComponent("Images/" + e.imageName), to: images.appendingPathComponent(name))
            try fm.copyItem(at: folder.appendingPathComponent("Images/" + e.thumbnailName), to: images.appendingPathComponent("thumb-" + name))
            next.entries[i].imageName = name; next.entries[i].thumbnailName = "thumb-" + name
        }
        return try commit(next)
    }
    func deleteRecovery(_ folder: URL) throws {
        guard try recoveryBackups().contains(where: { $0.resolvingSymlinksInPath().standardizedFileURL.path == folder.resolvingSymlinksInPath().standardizedFileURL.path }) else { throw JournalError.invalidBackup }
        try fm.removeItem(at: folder)
    }
    // Streaming FNV-1a detects accidental corruption, not authenticity of an untrusted backup.
    private func checksum(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        var hash: UInt64 = 14695981039346656037
        while let chunk = try handle.read(upToCount: 65536), !chunk.isEmpty { for byte in chunk { hash = (hash ^ UInt64(byte)) &* 1099511628211 } }
        return String(hash, radix: 16)
    }
}
