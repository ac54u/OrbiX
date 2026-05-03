OrbiX 🌊
OrbiX 是一款专为极客与 Home-lab 玩家打造的极简、优雅且功能强大的 iOS 远程下载管理中枢。它不仅是一个下载控制器，更是一个拥有极致原生体验的移动端影音管家。

✨ 核心特性 (Features)
🎬 影音管家级的视觉享受
智能解析与刮削：内置强大正则引擎，自动清洗 PT/BT 命名，实时提取「片名、年份、文件大小、画质（4K REMUX / WEB-DL 等）」。

TMDB 无缝联动：双击列表卡片，瞬间呼出 Radarr 风格 的影视元数据面板（涵盖高清海报、横版剧照、剧情简介与评分）。

零延迟缓存架构：独创内存级缓存池（In-Memory Cache），在保证 3 秒高频轮询下载状态的同时，彻底杜绝 TMDB API 滥用与列表滑动闪烁。

🍎 极致的 Apple 原生体验
灵动岛 (Live Activities) 深度集成：启动任务即刻登岛，息屏或切换应用也能实时掌控下载速率与进度。

Cupertino 设计语言：纯正的“果味” UI。大标题导航、高级毛玻璃（Blur）遮罩、暗黑模式（Dark Mode）完美适配。

Taptic Engine 触感反馈：卡片长按菜单（ContextMenu）、侧滑操作（Slidable）、双击刮削均配有恰到好处的震动反馈。

🚀 全功能的远程控制
支持：启动、暂停、强制启动、强制校验、汇报、优先级调节（置顶/提高/降低）。

支持：带本地文件同步删除的安全销毁机制。

高级过滤：按状态、分类、标签、时间/大小/进度进行多维度排序与筛选。

高级骨架屏 (Skeleton Loading) 与空状态托盘优雅过渡。

🛠️ 技术栈 (Tech Stack)
Framework: Flutter (Dart)

UI Widgets: cupertino_icons, flutter_slidable

API Integration: HTTP requests (RESTful), TMDB API v3

Local Storage: shared_preferences

CI/CD: GitHub Actions (全自动构建 iOS IPA 与 Release 极客化发布)

📦 编译与运行 (Getting Started)
前置要求
  1.Flutter 环境已配置完毕 (推荐 Flutter 3.x 稳定版)。

  2.macOS 系统及最新版 Xcode（用于编译 iOS）。

  3.[TMDB (The Movie Database)](https://www.themoviedb.org/)的免费 API Key。

本地运行步骤
  1.克隆仓库

    Bash
    git clone https://github.com/ac54u/OrbiX.git
    cd OrbiX
  2.获取依赖

    Bash
    flutter pub get
  3.配置 TMDB API Key
    打开 lib/services/tmdb_service.dart 文件，将你的 API Key 填入：

    Dart
    static const String _apiKey = 'YOUR_TMDB_API_KEY_HERE'; 
  4.编译并运行到 iOS 模拟器/真机

    Bash
    flutter run -d ios
⚙️ 自动化构建 (CI/CD Pipeline)
本项目已配置基于 GitHub Actions 的全自动打包流水线。

如何触发云端打包并发布 Release？
无需在本地苦等 Xcode 编译，只需在本地终端执行：

    Bash
    git tag v1.0.0
    git push origin v1.0.0
    GitHub Actions 将自动拉取代码、配置 Flutter 环境、执行免签名编译 (--no-codesign)，并自动生成包含精美更新日志的 GitHub Release 和 .ipa 安装包，方便通过 TrollStore 等工具直接安装！

🤝 贡献与反馈 (Contributing)
如果你对 OrbiX 有任何改进建议，或者希望增加对其他下载器后端（如 Transmission, Aria2）的支持，欢迎提交 Issue 或 Pull Request。