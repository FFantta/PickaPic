# PickaPic

A local-first iOS photo journal. Keep one photograph and a few words each day, then turn the collection into a personal book.

## Local edition

- Camera and system photo picker, an optional 50-character caption, date backfill and editing.
- Nondestructive book framing: the full photograph stays intact.
- Photo calendar, page details, random memories and On This Day.
- Book title, cover photo, year/date range, month chapters and paginated PDF preview/export.
- Weekly and monthly photo collages, plus individual photo cards; sharing is always explicit.
- Versioned full backup packages, conflict previews and merge policies; 30-day Recently Deleted.
- Atomic local writes, previous-index recovery and migration from the original `photos.json` format.
- Optional local reminders and a privacy-preserving WidgetKit Home Screen shortcut.
- Simplified Chinese and English, selectable in Settings.

No accounts, servers, remote analytics, subscriptions or annual giveaway in this edition. iOS/device backups and user-selected Files providers may store exports according to the user's settings.

## Open in Xcode

Requirements: macOS with **Xcode 16 or later**, iOS 16 or later. The project uses Xcode 16 synchronized source groups. No third-party iOS dependencies.

1. Open `PickaPic/PickaPic.xcodeproj` and select the shared **PickaPic** scheme.
2. Select an iPhone simulator. Build and run. A simulator has no camera; import an image using Photos or drag an image into the simulator's Photos library.
3. For a device, choose your Development Team in both the app and widget targets. Update bundle identifiers and register a matching App Group in both entitlements and `WidgetBridge.group` / `PageProvider` when changing teams.
4. The shared App Group defaults to `group.ffantta.PickaPic`. It shares **only the number of pages and today's completion state**, never images or journal text.
5. First launch asks no permissions. Camera, Photos add-only and notifications are requested at the point of use. PhotosPicker does not require broad library access.

Unsigned CI build:

```sh
xcodebuild -project PickaPic/PickaPic.xcodeproj -scheme PickaPic \
  -sdk iphonesimulator -configuration Debug \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Architecture

`SwiftUI screens → @MainActor JournalStore → JournalRepository actor → versioned JSON index + immutable JPEG blobs`

The repository actor serializes mutations. Images are written before an atomically replaced index, so a failed replacement preserves the previous entry. Caption-only edits never re-encode historical photos. Calendar-day keys remain stable while traveling. Thumbnail views downsample images with ImageIO, instead of loading the whole journal into memory. Original legacy files remain available after migration; permanent deletion also removes matching legacy content.

`ExportService` renders PDFs and flattened JPEG sharing images locally. Book previews use PDFKit. The custom `.pickapic` package holds the manifest, image resources and streaming corruption checksums; it is a **directory package**, not a ZIP archive. Export it using Files, and select it from Restore. It contains private, unencrypted content. PDF is a reading edition, not a full backup or a printer-certified file.

See [local implementation & verification](docs/LOCAL_EDITION.md) and [design direction](PickaPic/Design/DIRECTION.md).

## Tests

```sh
swift test --jobs 1
```

Portable Foundation tests cover real file IO: atomic save/reopen, date validation, one-page-per-day rules, replacement/restore conflicts, damaged backup rejection, import idempotency, legacy migration, index recovery and permanent deletion. The GitHub workflow also builds the app and widget on a macOS runner. A Linux syntax check is not an iOS type check; native UI/device checks are recorded separately.

## Data recovery

- Before moving devices, export **Full backup** from Settings. Deleting the app may remove its local data.
- Restore validates the package and previews conflicting dates. Choose to keep or replace existing days. A pre-restore recovery package is retained in the app's Documents/Recovery folder.
- Existing local indexes that fail to decode can recover from the previous generation. If neither is readable, use an exported backup; damaged files are preserved for investigation.
- An app-local recovery copy is not protection against uninstall or device loss. Export to a separate destination regularly.

## Design

Paper-white canvas, ink typography, acid-lime actions, lilac book covers and sage calendar details. User photographs lead the interface. Original vector book and flower artwork are built in SwiftUI; reference layouts and third-party artwork are not copied into the app.
