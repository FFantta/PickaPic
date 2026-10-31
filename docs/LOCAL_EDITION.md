# Local edition implementation and verification

Scope update: annual giveaway, event identity, account service and all backend operations are excluded. This file supersedes those portions of the product SOP for this edition.

| SOP function | Implementation | Native verification needed |
| --- | --- | --- |
| F01 Onboarding | Skip/start, no account; permissions at use | Fresh install, VoiceOver |
| F02 Capture/import | Camera, PhotosPicker, progress/error handling | Device camera, limited/iCloud image |
| F03 Edit/replace | Explicit save, caption count, atomic replacement, discard confirmation | Keyboard and interruption |
| F04 Backfill | Date picker, EXIF date suggestion, conflict confirmation | Cross-time-zone device |
| F05 Calendar/detail | Gregorian month grid, month navigation, full detail | Small screen and large text |
| F06 Day counts | Stable Day value, unique live day | Foundation tests |
| F07 Memories | Random past page and same-date earlier years | Boundary empty states |
| F08 Book | Title/cover, year/range, exclusions, nondestructive crop | Cover and long caption layout |
| F09 PDF | Month chapters, page-per-day, PDFKit preview, cancel/share | PDF rendering and cancel on device |
| F10 Collages | Weekly/monthly and single cards, optional dates/captions | Share sheet and Files save |
| F11 Local storage | Actor, immutable blobs, atomic JSON, previous index | Device low-space simulation |
| F12 Backup/restore | Package, checksums, conflict preview, merge, recovery copy | Files providers and package handling |
| F13 Trash | 30 days, restoration conflicts, permanent delete | Date expiry and UI confirmation |
| F14 Reminder | Explicit opt-in, current timezone, rolling 14-day horizon | Permission states and notification delivery |
| F15 Widget | Real extension target, page count and Today deep link | Provisioned App Group + Home Screen |
| F18 Settings/privacy | Language, local storage, export/import, privacy and support link | Language and accessibility |

## Important limits

- No signed IPA, App Store submission or production release is made by this change.
- Reminders are a rolling 14-day schedule, refreshed when the app opens; a repeating reminder was intentionally avoided because it can nag after today's page is complete.
- Backup corruption checksums are FNV-1a, not cryptographic authenticity or encryption. Import validates filenames and refuses symlink resources; only import backups you trust.
- Full backups may contain all photos and consume substantial space. Ensure space in both the app and chosen destination.
- The book PDF is 7 × 9 inches, RGB, with no printer-specific bleed profile. Validate actual resolution, binding and color requirements before printing.
- Local recovery files can contain earlier journal content. They are separate backups; permanent deletion from the current journal cannot revoke previously exported copies.
- No analytics SDK or network client is included. Settings opens a mail composer through a mailto link only when the user chooses it.

## Manual release checklist

1. Run the macOS CI build and portable storage tests.
2. On a clean simulator, complete onboarding and import a real photo. Cancel a subsequent picker; confirm no page changes.
3. Add/edit/backfill the same day, reject then accept a replacement, restore the original from Trash.
4. Change time zone, reopen, and confirm stable page dates. Check February and leap-year months.
5. Generate a book with mixed portrait/landscape images and a 50-character multilingual caption; inspect every page and cover.
6. Export full backup to Files, restore into a clean install, compare dates/captions/photos. Try a damaged package and both conflict policies.
7. On a device, grant/deny camera, Photos add-only and notifications; confirm local save survives a Photos-copy failure.
8. Add the signed widget; change journal data and test its Today deep link. Confirm no private image/text appears.
9. Enable Dynamic Type and VoiceOver. Check a small iPhone and landscape iPad before release.
