# 📅 CoolCalendar - 高效日历与日程管理应用

CoolCalendar 是一个跨平台的移动日历应用，使用 Flutter 构建。它提供了一个直观的日历视图，支持事件创建、管理、提醒通知，并集成了 iCalendar (ICS) 订阅功能，帮助用户高效管理个人和订阅日程。

## ✨ 主要功能特性

* **日程管理:** 创建、查看、修改和删除日程事件。
* **日历视图:** 提供月视图、周视图等多种日历格式，支持快速切换和导航。
* **持久化存储:** 使用 **SQLite** 本地数据库（通过 `sqflite` 库）安全存储所有日程数据。
* **事件提醒:** 集成本地通知 (`flutter_local_notifications`)，为重要事件提供精确的定时提醒。
* **iCalendar (ICS) 订阅:**
    * 支持通过 URL 订阅外部日历（如学校课表、公共假期）。
    * 自动解析 ICS 文件格式，导入订阅事件。
* **数据导入/导出:** 支持将日程数据导出为 JSON 文件，并允许从本地文件导入数据。
* **农历显示:** 集成农历（Lunar）支持，提供更符合传统习惯的日历信息。
* **自定义颜色:** 为事件设置不同的标签颜色，便于分类和视觉区分。

## 🛠️ 技术栈与依赖

本项目基于 Flutter 框架开发，主要依赖项在 `pubspec.yaml` 中定义：

| 类别 | 库名 | 用途 |
| :--- | :--- | :--- |
| **框架** | `flutter` | 核心跨平台 UI 框架 |
| **日历/UI** | `table_calendar` | 灵活的日历组件 |
| **状态管理** | `provider` | 应用程序状态管理 |
| **数据持久化** | `sqflite`, `path` | SQLite 数据库操作和路径管理 |
| **通知** | `flutter_local_notifications` | 本地定时提醒服务 |
| **时区** | `timezone`, `flutter_timezone` | 准确的时区处理，确保提醒准时 |
| **网络/数据** | `http`, `icalendar_parser` | 网络请求和 ICS 文件解析 |
| **工具** | `uuid`, `intl`, `lunar` | 唯一ID生成、国际化日期格式化、农历转换 |
| **文件操作** | `path_provider`, `file_picker`, `share_plus` | 文件路径获取、文件选择、系统分享 |

## 🚀 运行项目

### 预备条件

1.  安装 [Flutter SDK](https://flutter.dev/docs/get-started/install)。
2.  配置好 Android 或 iOS 开发环境。

### 步骤

1.  **克隆仓库：**
    ```bash
    git clone [https://github.com/ahia11/cool_calendar.git]
    cd calendar_app
    ```

2.  **获取依赖：**
    ```bash
    flutter pub get
    ```

3.  **运行应用：**
    ```bash
    flutter run
    ```
    
## 📂 项目结构概览

以下是项目关键文件及其职责：

| 文件/目录 | 职责描述 |
| :--- | :--- |
| `lib/main.dart` | 应用入口文件，负责初始化 Flutter 绑定、通知服务、时区以及 Provider 状态管理。 |
| `lib/pages/calendar_page.dart` | 日历和事件列表的 UI 界面，包含添加/删除事件的交互逻辑。 |
| `lib/models/event_model.dart` | **事件数据模型 (Event Model)**，定义事件结构，包含 `toMap()` 和 `fromMap()` 用于数据库转换。 |
| `lib/providers/event_provider.dart` | **状态管理核心**，管理事件列表 (`_events`)，包含 CRUD 操作、ICS 订阅、数据导入导出等核心业务逻辑。 |
| `lib/services/database_helper.dart` | **SQLite 数据库服务**，负责数据库连接 (`_initDB`)、表创建 (`_createDB`) 以及对 `events` 表的 CRUD 操作。 |
| `lib/services/notification_service.dart` | **本地通知服务**，负责初始化通知设置、请求权限以及精确安排定时提醒 (`scheduleNotification`)。 |
| `pubspec.yaml` | Flutter 依赖配置文件，列出了所有第三方库及其版本。 |
| `android/AndroidManifest.xml` | Android 配置文件，声明了应用所需的权限，如 `RECEIVE_BOOT_COMPLETED` (启动通知)、`SCHEDULE_EXACT_ALARM` (精确闹钟) 和 `INTERNET` (网络订阅)。 |

## 🔧 数据库设计

本项目使用 SQLite 数据库存储事件。表结构定义在 `lib/services/database_helper.dart` 中：

**表名:** `events`

| 字段名 | 类型 | 描述 |
| :--- | :--- | :--- |
| `id` | `TEXT PRIMARY KEY` | 事件唯一标识 (UUID) |
| `title` | `TEXT NOT NULL` | 事件标题 |
| `description` | `TEXT` | 事件详细描述 (可空) |
| `date` | `TEXT NOT NULL` | 事件时间 (存储为 ISO 8601 字符串) |
| `is_all_day` | `INTEGER NOT NULL` | 是否为全天事件 (0/1) |
| `is_subscribed` | `INTEGER NOT NULL` | 是否来自订阅 (0/1) |
| `color_value` | `INTEGER` | 事件标签颜色值 (`Color.value` 整数) (可空) |