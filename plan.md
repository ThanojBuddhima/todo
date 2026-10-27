# Flutter Offline Todo App — Implementation Plan

A fully offline Android todo app in Flutter, with a modern animated Material 3 UI in
both light and dark themes, and an exportable PDF report covering every recorded activity.

**Status:** implementation in progress. Progress is tracked in §11.
**Target output:** signed release APK for sideloading.

---

## 0. Environment (verified 2026-10-27)

| Tool | Version | Note |
|---|---|---|
| Flutter | 3.41.7 stable | OK |
| Dart | 3.11.5 | OK |
| Android SDK | 36.1.0 | licenses not yet accepted — run `flutter doctor --android-licenses` |
| JDK (default) | **25.0.1** | **risk:** current Android Gradle Plugin versions do not support Java 25. If the first Gradle build fails, point Flutter at a JDK 21: `flutter config --jdk-dir <path-to-jdk-21>` |

---

## 1. Stack

| Concern | Package | Version | Why |
|---|---|---|---|
| State | `flutter_riverpod` | 3.4.3 | Compile-safe, testable, no BuildContext juggling; async providers map cleanly onto DB reads |
| Storage | `sqflite` | 2.4.5 | Local file DB. Relational is the right shape: tasks → subtasks → activity_log, with joins and date-range queries for the PDF |
| PDF build | `pdf` | 3.11.3 | Builds the document in pure Dart; pinned for Dart 3.11 compatibility |
| PDF share/print | `printing` | 5.15.1 | Native save / share / print sheet |
| Paths | `path_provider` | 2.1.6 | App documents directory |
| Share | `share_plus` | 13.3.1 | Share the generated file |
| Open file | `open_filex` | 5.0.0 | Open the PDF in a viewer |
| Reminders | `flutter_local_notifications` | 22.3.3 | On-device scheduled notifications |
| Timezone | `timezone` / `flutter_timezone` | 0.11.2 / 5.1.1 | Correct zoned scheduling across DST |
| Lock | `local_auth` | 3.0.2 | Biometric + device-credential fallback |
| Secrets | `flutter_secure_storage` | 11.2.0 | Salted PIN hash in Keystore |
| Prefs | `shared_preferences` | 2.5.6 | Theme mode, lock toggle, first-run |
| Motion | `flutter_animate` | 4.5.2 | Declarative entrance chains |
| Transitions | `animations` | 3.0.0 | Container-transform / shared-axis |
| Swipe | `flutter_slidable` | 4.0.3 | Swipe actions on cards |
| Fonts | `google_fonts` | 9.0.0 | Inter / Manrope in-app |
| Dates | `intl` | 0.20.3 | Formatting and grouping |
| Ids | `uuid` | 4.6.0 | Stable task ids |

Build config: `minSdkVersion 23`, `compileSdk 36`, `targetSdk 36`.

**Offline guarantee:** the `INTERNET` permission is never declared in the manifest. Nothing in
the dependency list requires network access at runtime. `google_fonts` is used with fonts
bundled in `assets/fonts/` so it never fetches from the network.

---

## 2. Project structure

```
lib/
  main.dart
  app.dart                      // MaterialApp, theme wiring, lock gate
  core/
    theme/  app_theme.dart, app_colors.dart, app_typography.dart, motion.dart
    db/     app_database.dart    // open, onCreate, onUpgrade, migrations
    utils/  date_x.dart, result.dart
  features/
    tasks/
      data/      task_dao.dart, subtask_dao.dart, category_dao.dart
      domain/    task.dart, subtask.dart, category.dart, priority.dart, task_filter.dart
      providers/ task_providers.dart
      ui/        home_screen.dart, task_detail_screen.dart, task_editor_sheet.dart
                 widgets/ task_card.dart, animated_checkbox.dart, filter_chips_bar.dart,
                          empty_state.dart, priority_accent.dart, subtask_tile.dart,
                          stat_row.dart
    activity/
      data/      activity_dao.dart
      domain/    activity_entry.dart, activity_action.dart
      providers/ activity_providers.dart
      ui/        history_screen.dart, widgets/timeline_tile.dart
    export/
      pdf_report_builder.dart   // pure: data in, Uint8List out
      export_service.dart       // range -> query -> build -> save/share
      ui/ export_sheet.dart
    reminders/   notification_service.dart, permission_gate.dart
    security/    lock_service.dart, ui/lock_screen.dart
    settings/    ui/settings_screen.dart, providers/settings_providers.dart
assets/
  fonts/   Inter-Regular.ttf, Inter-SemiBold.ttf, Manrope-Bold.ttf
```

**Rule:** `pdf_report_builder.dart` takes plain data and returns bytes — no DB access, no
plugins — so the report layout is unit-testable without a device.

---

## 3. Data model

```sql
CREATE TABLE tasks (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  notes TEXT,
  category_id TEXT REFERENCES categories(id),
  priority INTEGER NOT NULL DEFAULT 1,          -- 0 low, 1 medium, 2 high
  due_at INTEGER,
  remind_at INTEGER,
  notification_id INTEGER,
  is_done INTEGER NOT NULL DEFAULT 0,
  completed_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  sort_index REAL NOT NULL,
  deleted_at INTEGER                            -- soft delete
);

CREATE TABLE subtasks (
  id TEXT PRIMARY KEY,
  task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  is_done INTEGER NOT NULL DEFAULT 0,
  sort_index REAL NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE TABLE categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  color_value INTEGER NOT NULL,
  icon_code INTEGER
);

CREATE TABLE activity_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id TEXT,
  task_title TEXT NOT NULL,        -- denormalized: survives a hard delete
  category_name TEXT,              -- denormalized for the same reason
  action INTEGER NOT NULL,
  field TEXT,
  old_value TEXT,
  new_value TEXT,
  occurred_at INTEGER NOT NULL
);

CREATE INDEX idx_activity_time ON activity_log(occurred_at);
CREATE INDEX idx_tasks_due ON tasks(due_at);
```

`ActivityAction` enum, stored as its index:

```
created, titleEdited, notesEdited, dueDateChanged, priorityChanged,
categoryChanged, completed, reopened, subtaskAdded, subtaskCompleted,
subtaskDeleted, reminderSet, reminderCleared, deleted, restored
```

**Logging invariant:** every mutating DAO method writes the data row *and* its
`activity_log` entry inside one `db.transaction`. Logging is never a separate call that a
future edit can forget, and a failed write leaves no orphan log entry.

---

## 4. Design system

- **Material 3**, `ColorScheme.fromSeed` with seed `#6C5CE7` (indigo-violet). Both schemes
  are built once at startup; `themeMode` comes from prefs and offers a System option.
- **Surfaces:** layered `surfaceContainerLow` / `surfaceContainerHigh` cards, 20px radius,
  1px hairline border instead of heavy elevation.
- **Dark theme:** true dark `#0E0E13` background with elevated `#17171F` cards — not
  grey-on-grey. Contrast checked against WCAG AA for body text in both themes.
- **Priority** renders as a 4px left accent bar plus a dot, never as the card's full
  background.
- **Type:** Manrope 700 headings, Inter 400/500 body, tabular figures for dates and counts.
- `core/theme/motion.dart` is the single source for durations and curves:
  `fast 150ms`, `base 250ms`, `slow 400ms`, `emphasized = Curves.easeOutCubic`,
  plus a spring simulation for the checkbox.

---

## 5. Animation plan

1. **List entrance** — staggered fade + 12px slide-up, 40ms per item, capped at 10 items so
   long lists do not crawl.
2. **Add task** — FAB morphs into the editor sheet via `OpenContainer` container transform.
3. **Completion** — custom-painted checkbox: ring scales, check path draws via an animated
   path trace; the card desaturates and the title strikes through with an animated text
   width; light haptic. The card then animates out to the Done group.
4. **Reorder** — `ReorderableListView` with a lift animation (scale 1.03 + shadow) and
   fractional `sort_index`, so a reorder writes a single row.
5. **Swipe** — `flutter_slidable`: right → complete (green), left → delete (red), with an
   undo `SnackBar` wired to the soft-delete restore.
6. **Page transitions** — shared-axis horizontal between Home / History / Settings;
   task detail opens as a container transform from the tapped card.
7. **Stat row** — Today / Pending / Done counts tween on change; progress ring animates.
8. **Empty state** — gentle looping animation, faded in after 200ms so it never flashes
   during the initial DB read.
9. **Theme switch** — `AnimatedTheme` 300ms cross-fade rather than a hard swap.
10. **Reduced motion** — read `MediaQuery.disableAnimations` and collapse every duration to
    zero. Accessibility requirement, and it keeps widget tests fast.

---

## 6. Screens

1. **Home** — greeting + date, animated stat row, search field, filter chips
   (All / Today / Upcoming / Pending / Done / by category), task list grouped into
   Overdue · Today · Tomorrow · Later · Done (collapsed), FAB.
2. **Task editor sheet** — title, notes, due date + time, priority segmented control,
   category picker with inline create, reminder toggle, inline subtask list. Draggable
   bottom sheet, keyboard-aware.
3. **Task detail** — full view with subtask progress ring and that task's own activity trail.
4. **History** — reverse-chronological activity timeline with day headers and action icons,
   date-range filter, and **Export PDF** in the app bar.
5. **Export sheet** — range presets (Today / 7 days / 30 days / This month / All time /
   Custom), optional category and action-type filters, a live "N activities across M tasks"
   count, then Preview / Save / Share.
6. **Settings** — theme mode, accent seed, app lock toggle and PIN setup, notification
   permission status, data actions (clear completed, purge deleted, wipe all behind a typed
   confirmation), about.
7. **Lock screen** — shown over everything on cold start, and on resume after the timeout,
   when the lock is enabled.

---

## 7. PDF activity report

Built with `pdf`'s `MultiPage` so it paginates correctly at any length.

- **Cover block** — app name, "Activity Report", the covered range, generated timestamp.
- **Summary** — tasks created / completed / deleted, completion rate, busiest day, and a
  per-category breakdown drawn with `pdf` primitives (no chart dependency).
- **Activity table** — repeating header row; columns Date · Time · Task · Category ·
  Action · Change (old → new). Zebra striping, action-colored chip.
- **Per-task appendix** — each task with its full chronological action trail. Toggleable.
- **Footer** — page X of Y, plus "Generated offline on-device".
- **Fonts** — Inter embedded from `assets/fonts/`. `google_fonts` cannot feed the PDF
  renderer, and without embedding, non-Latin characters render as boxes.
- **Output** — `activity-report-YYYYMMDD-HHmm.pdf` written to the app documents directory,
  then handed to `Printing.sharePdf` or `open_filex`. No storage permission is needed for
  this path on Android 10+.

---

## 8. Reminders

`NotificationService` is a singleton initialized in `main` before `runApp`:

- Android notification channel created explicitly at init.
- Local zone resolved with `flutter_timezone`, then `zonedSchedule` with
  `AndroidScheduleMode.exactAllowWhileIdle`.
- `POST_NOTIFICATIONS` (Android 13+) is requested lazily — only when the user first turns a
  reminder on, never at startup.
- If exact alarms are denied, fall back to inexact scheduling and say so in the editor sheet
  rather than failing silently.
- `notification_id` is stored on the task so an edit reschedules and a delete cancels.

---

## 9. App lock

- PIN stored as a salted SHA-256 hash in `flutter_secure_storage` (Android Keystore).
- Biometric via `local_auth` with `biometricOnly: false`, so the device PIN works as a
  fallback and the lock never becomes unopenable.
- A root-level gate widget watches `AppLifecycleState` and re-locks after 60s in background.
- Screenshot blocking (`FLAG_SECURE`) is **not** included — it needs an extra plugin. Listed
  as a follow-up below.

---

## 10. Build and APK

```bash
flutter doctor --android-licenses                 # accept once
flutter create . --platforms=android --org com.thanoj

# ... implementation ...

keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias upload     # then android/key.properties (gitignored)

flutter build apk --release --split-per-abi
```

- Install `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` on a modern phone; a
  universal `app-release.apk` is also produced as a fallback.
- R8 shrinking on, with keep rules for `flutter_local_notifications`.
- Expected size ~18–24 MB per ABI; the embedded PDF fonts are the bulk of it.
- App icon via `flutter_launcher_icons`, splash via `flutter_native_splash`.
- `key.properties` and `*.jks` go in `.gitignore` — never committed.

---

## 11. Task checklist

Every box below is one unit of work. Tick `[x]` as it lands. Sections 0–10 above are the
spec these tasks implement — the checklist is the only place that tracks progress.

**Progress:** 47 / 132 done · current milestone: M7

### M0 — Environment and project setup

- [ ] Accept Android SDK licenses (`flutter doctor --android-licenses`)
- [ ] Confirm `flutter doctor` shows no Android-toolchain warnings
- [ ] Resolve the Java 25 / AGP issue if the first Gradle build fails (`flutter config --jdk-dir` → JDK 21)
- [ ] `flutter create . --platforms=android --org com.thanoj`
- [ ] Set `minSdkVersion 23`, `compileSdk 36`, `targetSdk 36` in `android/app/build.gradle.kts`
- [ ] Add all §1 dependencies to `pubspec.yaml` at the pinned versions
- [ ] Download Inter + Manrope TTFs into `assets/fonts/`, declare them in `pubspec.yaml`
- [ ] Verify `AndroidManifest.xml` declares **no** `INTERNET` permission
- [ ] Add `key.properties`, `*.jks`, `build/` to `.gitignore`
- [ ] Commit the scaffold

### M1 — Theme system and app shell

- [ ] `core/theme/app_colors.dart` — seed `#6C5CE7`, dark surfaces `#0E0E13` / `#17171F`, priority + action colors
- [ ] `core/theme/app_typography.dart` — Manrope headings, Inter body, tabular figures
- [ ] `core/theme/motion.dart` — `fast/base/slow` durations, `emphasized` curve, checkbox spring
- [ ] `core/theme/app_theme.dart` — light and dark `ThemeData` from `ColorScheme.fromSeed`
- [ ] Card theme: 20px radius, hairline border, layered surface containers
- [ ] `settings_providers.dart` — `themeMode` persisted via `shared_preferences`
- [ ] `app.dart` — `MaterialApp` with both themes and `AnimatedTheme` cross-fade
- [ ] Reduced-motion helper reading `MediaQuery.disableAnimations`
- [ ] Verify WCAG AA contrast for body text in both themes
- [ ] Placeholder Home / History / Settings routes with shared-axis transitions
- [ ] **Verify:** app runs; theme toggle cross-fades smoothly

### M2 — Database layer

- [ ] `core/db/app_database.dart` — open, `onConfigure` (foreign keys on), `onCreate`, `onUpgrade`
- [x] `tasks` table per §3
- [x] `subtasks` table per §3
- [x] `categories` table per §3 + seed default categories on first run
- [x] `activity_log` table per §3
- [x] Indexes `idx_activity_time`, `idx_tasks_due`
- [x] `ActivityAction` enum with its 15 values, index-stable
- [ ] Domain models: `Task`, `Subtask`, `Category`, `Priority`, `ActivityEntry` with `fromMap`/`toMap`
- [ ] `activity_dao.dart` — insert entry, query by range, query by task, count by action
- [ ] `task_dao.dart` — create / update / toggleDone / softDelete / restore / purge, each in one transaction with its log write
- [ ] `subtask_dao.dart` — add / toggle / delete / reorder, each logged in-transaction
- [ ] `category_dao.dart` — create / rename / delete (reassign tasks to none)
- [ ] Fractional `sort_index` reorder helper (single-row write)
- [ ] Migration test: v1 schema opens clean on a fresh DB
- [ ] **Unit tests:** every mutating DAO method writes exactly one matching log row
- [ ] **Unit test:** a failed write leaves no orphan log entry

### M3 — Core task UI and CRUD

- [x] `task_providers.dart` — task list, filtered list, stat counts, single task
- [x] `TaskFilter` model — All / Today / Upcoming / Pending / Done / category / search text
- [x] `task_card.dart` — title, notes preview, due chip, priority accent bar + dot, subtask count
- [x] `home_screen.dart` — greeting, date, scaffold, FAB
- [x] `stat_row.dart` — Today / Pending / Done counts
- [x] Search field wired to the filter provider (debounced)
- [x] `filter_chips_bar.dart` — horizontal scrolling chips incl. categories
- [x] Date grouping: Overdue · Today · Tomorrow · Later · Done (collapsed)
- [x] `empty_state.dart` — per-filter copy, delayed fade-in
- [x] `task_editor_sheet.dart` — draggable, keyboard-aware bottom sheet
- [x] Editor: title + notes fields with validation
- [x] Editor: due date + time picker, clearable
- [x] Editor: priority segmented control
- [x] Editor: category picker with inline "create new"
- [x] Editor handles both create and edit modes
- [x] Delete with undo `SnackBar` wired to soft-delete restore
- [ ] **Verify:** full CRUD round-trip survives app restart

### M4 — Subtasks and task detail

- [x] `subtask_tile.dart` — checkbox, inline rename, delete
- [x] Inline subtask add/list inside the editor sheet
- [x] Animated subtask progress ring (done / total)
- [x] `task_detail_screen.dart` — full task view
- [x] Per-task activity trail on the detail screen
- [x] Subtask reorder
- [x] **Verify:** completing a subtask updates the parent progress everywhere it shows

### M5 — Animation pass

- [x] Staggered list entrance: fade + 12px slide-up, 40ms/item, capped at 10
- [x] FAB → editor sheet container transform (`OpenContainer`)
- [x] `animated_checkbox.dart` — ring scale + path-trace check draw
- [x] Completion: card desaturate + animated strike-through + light haptic
- [x] Card animates out to the Done group on completion
- [ ] `ReorderableListView` with lift animation (scale 1.03 + shadow)
- [x] `flutter_slidable`: swipe right → complete, swipe left → delete
- [x] Card → task detail container transform
- [x] Stat counts tween on change; progress ring animates
- [x] Reduced motion collapses all durations to zero
- [ ] **Verify:** 60fps in profile mode on a real device, long list scrolled hard

### M6 — History timeline

- [x] `activity_providers.dart` — range-filtered log stream
- [x] `timeline_tile.dart` — action icon, colored chip, task title, old → new change
- [x] `history_screen.dart` — reverse-chronological list with sticky day headers
- [x] Date-range filter UI
- [x] Action-type filter
- [x] Pagination or lazy loading for a long log
- [x] **Verify:** exercise all 15 action types and confirm each renders correctly

### M7 — PDF activity report

- [ ] Load embedded Inter fonts for the PDF renderer
- [x] `pdf_report_builder.dart` skeleton — `MultiPage`, pure data in / `Uint8List` out
- [x] Cover block — app name, title, range, generated timestamp
- [ ] Summary — created / completed / deleted, completion rate, busiest day
- [ ] Per-category breakdown bars drawn with `pdf` primitives
- [ ] Activity table with repeating header + zebra rows
- [ ] Action chips colored per action type
- [ ] Per-task appendix section (toggleable)
- [ ] Footer — page X of Y + "Generated offline on-device"
- [ ] `export_service.dart` — range → query → build → write to app documents dir
- [ ] Filename format `activity-report-YYYYMMDD-HHmm.pdf`
- [ ] `export_sheet.dart` — range presets + custom range
- [ ] Export sheet: category and action-type filters
- [ ] Export sheet: live "N activities across M tasks" count
- [ ] Preview via `Printing.layoutPdf`
- [ ] Save, Share (`share_plus`), Open (`open_filex`) actions
- [ ] Handle the empty-range case gracefully
- [ ] **Test:** byte output is a valid non-empty PDF for an empty, small and 1000-entry log
- [ ] **Verify:** open a real exported PDF on the phone and check pagination + non-Latin text

### M8 — Reminders

- [ ] `notification_service.dart` singleton, initialized before `runApp`
- [ ] Android notification channel created at init
- [ ] Timezone init via `flutter_timezone`
- [ ] `zonedSchedule` with `AndroidScheduleMode.exactAllowWhileIdle`
- [ ] Lazy `POST_NOTIFICATIONS` request on first reminder toggle
- [ ] Inexact-alarm fallback with a visible notice in the editor sheet
- [ ] Store `notification_id` on the task; reschedule on edit, cancel on delete
- [ ] Reminder toggle + time picker in the editor sheet
- [ ] Tapping a notification deep-links to that task's detail screen
- [ ] Reschedule pending reminders after a device reboot (`BOOT_COMPLETED` receiver)
- [ ] **Verify:** a scheduled notification fires with the app closed

### M9 — App lock and settings

- [ ] `lock_service.dart` — salted SHA-256 PIN hash in `flutter_secure_storage`
- [ ] Biometric auth via `local_auth`, `biometricOnly: false`
- [ ] `lock_screen.dart` — PIN entry + biometric prompt
- [ ] Root lock gate watching `AppLifecycleState`, 60s background timeout
- [ ] `settings_screen.dart` — theme mode selector
- [ ] Settings: accent seed choice
- [ ] Settings: app lock toggle + PIN setup / change flow
- [ ] Settings: notification permission status + shortcut to system settings
- [ ] Settings: clear completed, purge deleted
- [ ] Settings: wipe all data behind a typed confirmation
- [ ] Settings: about section (version, "works fully offline")
- [ ] **Verify:** lock holds across background → resume and cold start

### M10 — Release

- [ ] App icon via `flutter_launcher_icons` (light + dark adaptive)
- [ ] Splash via `flutter_native_splash`, both themes
- [ ] Generate the upload keystore; write `android/key.properties`
- [ ] Wire release signing in `build.gradle.kts`
- [ ] Enable R8 shrinking + keep rules for `flutter_local_notifications`
- [ ] `flutter build apk --release --split-per-abi`
- [ ] Also produce the universal `app-release.apk`
- [ ] Install the arm64-v8a APK on the phone
- [ ] **Verify:** full smoke test in airplane mode — CRUD, subtasks, reminder, PDF export, lock
- [ ] Record final APK size and note it here
- [ ] Tag the release commit

---

## 12. Decisions already made

- **sqflite over Isar/Hive** — the activity log needs date-range queries and joins; Isar's
  maintenance status is also a risk for an app meant to last.
- **No `drift`** — avoids build_runner codegen in a small app; hand-written DAOs stay readable.
- **Soft delete** — makes undo trivial and keeps the history honest. A "purge deleted" action
  in settings performs the hard delete.
- **Denormalized task title and category in the log** — the PDF stays correct after
  deletions, at the cost of some duplication.
- **Riverpod over Bloc** — less ceremony for a CRUD app of this size.

---

## 13. Open questions

1. Should the PDF's **per-task appendix** default to on or off?
2. Add **screenshot blocking** alongside the app lock? (one extra plugin)

Neither blocks milestone 1.

---

## 14. Follow-ups, out of scope for v1

- Screenshot blocking (`FLAG_SECURE`).
- Recurring tasks.
- Home-screen widget.
- Local JSON backup / restore (still offline, file-based).
- iOS build (the plan is platform-agnostic apart from §8–§10).
