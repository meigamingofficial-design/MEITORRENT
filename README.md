# 🌸 Meitorrent

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-green.svg?style=flat)](https://android.com)
[![License](https://img.shields.io/badge/License-GPL%20v3-blue.svg?style=flat)](LICENSE)

A production-grade, highly optimized Android torrent client powered by **libtorrent 2.0 (C++ native)** and beautifully designed using a **Japanese Sumi-e & Sakura Parchment** aesthetic.

---

## 🎨 Design System & Visuals

Meitorrent is designed to look like a hand-painted Japanese parchment scroll:
*   **Backgrounds**: Soft, textured ivory parchment (`#FCF3F3` / `#FAF6EE`).
*   **Primary Highlights**: Vibrant hand-painted **Sakura Pink** (`#FF3B7B`) and **Blossom Crimson** (`#D81B60`).
*   **Inkwork**: Sumi-e charcoal black (`#1C1C1C`) for text and vector paths.
*   **Watermarks**: Delicate, translucent cherry blossom (Sakura) background patterns flowing across navigation boundaries.

---

## 🚀 Core Features

*   **Libtorrent 2.0 Core**: High-performance, memory-safe native C++ torrent engine (via Dart FFI).
*   **Reliable Background Tasking**: Dynamic foreground service guard ensuring background downloads are never suspended by the OS battery manager.
*   **Intelligent Safety Guards**:
    *   **Disk Space Guard**: Auto-pauses downloading when available free storage drops below 100 MB.
    *   **Bandwidth & Network Guard**: Pauses/Resumes downloads dynamically based on network state (e.g., WiFi-only constraints).
    *   **OEM Battery Guard**: Alerts the user about aggressive OEM background process killing to ensure uninterrupted task completion.
*   **Full-Bleed Adaptive Icons**: Custom-scaled (70%) adaptive launcher icons utilizing the exact `#FAF6EE` background hex to ensure perfect circles/squircles with **zero clipping**.

---

## 🏗️ Architecture & Stack

The codebase is engineered around **Feature-First Clean Architecture**:
*   **Presentation**: Riverpod + Hooks (StateNotifier & AsyncNotifier) for predictable, reactive UI updates.
*   **Domain**: Clear entity definitions and abstract repository interfaces separating business logic from direct network/database drivers.
*   **Data**: Drift (Sqlite3) for persistent, batched snapshot saves, alongside the native C++ FFI bindings to libtorrent.

---

## 📦 Multi-Flavor Environment

Meitorrent supports three separate build flavors (configured with separate Application IDs for side-by-side installations):

| Flavor | App Name | Application ID |
| :--- | :--- | :--- |
| **`dev`** | Meitorrent Dev | `com.meigaming.meitorrent.dev` |
| **`staging`** | Meitorrent Staging | `com.meigaming.meitorrent.staging` |
| **`prod`** | Meitorrent | `com.meigaming.meitorrent` |

### 🛠️ Development & Build Commands

#### 📦 Building APKs & AppBundles
To build the distribution files for the Play Store or manual installation:
```bash
# Production Release APK
flutter build apk --flavor prod --release

# Production Release AppBundle (For Play Store)
flutter build appbundle --flavor prod --release

# Staging Release APK
flutter build apk --flavor staging --release

# Development Release APK
flutter build apk --flavor dev --release
```

To run a specific flavor directly on a connected device:
```bash
flutter run --flavor dev
```

#### 🔄 Code Generation (Drift & Riverpod)
To trigger the code generator for database models and providers:
```bash
# One-time build (Recommended after schema changes)
dart run build_runner build --delete-conflicting-outputs

# Live-watch mode (Automatically builds on save)
dart run build_runner watch --delete-conflicting-outputs
```

#### 🩺 Quality Assurance (Formatting, Lints & Tests)
To format code, analyze rules, and run all automated tests before making a commit:
```bash
# Auto-format all Dart files in the workspace
dart format .

# Check for code quality, analyzer warnings, and lints
dart analyze

# Run the complete unit and widget test suite
flutter test
```

#### 🧹 Maintenance & Cleaning
If you run into compilation caches, stale assets, or want to reclaim disk space from unused package versions, perform a clean sweep:
```bash
# Wipe out build artifacts and build cache
flutter clean

# Fetch and sync package dependencies
flutter pub get

# Garbage-collect unused packages from the global pub cache to free up disk space
dart pub cache gc
```

---

## ⚖️ License

This project is open-source and distributed under the terms of the **GNU General Public License v3 (GPLv3)**. See [LICENSE](LICENSE) and [LICENSES.md](LICENSES.md) for more information.

---

## 🔒 Privacy & Legal

- **Privacy Policy**: Hosted live at [meigamingofficial-design.github.io/MEITORRENT/privacy-policy.html](https://meigamingofficial-design.github.io/MEITORRENT/privacy-policy.html)
- **Terms & Conditions**: Hosted live at [meigamingofficial-design.github.io/MEITORRENT/terms.html](https://meigamingofficial-design.github.io/MEITORRENT/terms.html)
