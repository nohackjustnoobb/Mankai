> [!WARNING]
> This project is currently under active development. Many details are still being finalized.

<div align="center">

<img src="assets/icon.png" width="128" />

# Mankai

<!-- [![Swift](https://img.shields.io/badge/swift-F54A2A?style=for-the-badge&logo=swift&logoColor=white)](https://developer.apple.com/swift/) -->

[![GitHub License](https://img.shields.io/github/license/nohackjustnoobb/Mankai?style=for-the-badge)](https://github.com/nohackjustnoobb/Mankai/blob/master/LICENSE)
[![GitHub last commit](https://img.shields.io/github/last-commit/nohackjustnoobb/Mankai?style=for-the-badge)](https://github.com/nohackjustnoobb/Mankai/commits/master)
[![GitHub stars](https://img.shields.io/github/stars/nohackjustnoobb/Mankai?style=for-the-badge)](https://github.com/nohackjustnoobb/Mankai/stargazers)

</div>

Mankai is a powerful and extensible manga reader for iPhone and iPad, written in Swift. It features a **plugin system** for multi-source support (JavaScript & filesystem), **library management** to organize your collection, **reading history** tracking, and a **modern UI** built with SwiftUI.

![Demo](assets/demo.png)

<details>
<summary>More Screenshots</summary>

### iPhone

|               Home               |                Library                 |                Details                 |
| :------------------------------: | :------------------------------------: | :------------------------------------: |
| ![Home](assets/iphone-home.jpeg) | ![Library](assets/iphone-library.jpeg) | ![Details](assets/iphone-details.jpeg) |

### iPad

|              Home              |               Library                |               Details                |
| :----------------------------: | :----------------------------------: | :----------------------------------: |
| ![Home](assets/ipad-home.jpeg) | ![Library](assets/ipad-library.jpeg) | ![Details](assets/ipad-details.jpeg) |

</details>

## Plugins

Mankai supports extensions through JsPlugin and FsPlugin.

### JavaScript Plugin (JsPlugin)

You can find the official plugins in the [Mankai Plugins](https://github.com/nohackjustnoobb/Mankai-Plugins) repository.

- **Source Code**: [nohackjustnoobb/Mankai-Plugins](https://github.com/nohackjustnoobb/Mankai-Plugins)
- **Compiled Plugins**: [static branch](https://github.com/nohackjustnoobb/Mankai-Plugins/tree/static)

### File System Plugin (FsPlugin)

The **FsPlugin** allows you to choose a folder to store or read manga from. This folder can be shared across different devices using iCloud Drive or other remote storage solutions (like SMB).

### Http Plugin (HttpPlugin) (Planned)

The **HttpPlugin** will connect to external sources that provide a standard API for Mankai. An official implementation of a standard HTTP server will also be maintained.

## Syncing

Mankai supports syncing your library and reading history across devices. Currently, only one sync engine is implemented:

### HttpEngine

The **HttpEngine** requires a self-hosted server to function. You can host the server yourself using the [Mankai-Sync](https://github.com/nohackjustnoobb/Mankai-Sync) repository.

Once hosted, you can configure the server URL in the app settings to enable syncing.

### Planned Sync Engines

- **Supabase**
- **iCloud** - Pending availability of resources (aka. I have no money)

## Development Notes

**Performance with Debugger Attached (e.g., from Xcode):**

- The startup time will be significantly slower than normal.
- The app may temporarily freeze on the first scroll in the reader screen.

These issues do not occur when running the app without a debugger attached.
