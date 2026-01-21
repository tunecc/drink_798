# 💧 智能饮水 (Smart Drink Water)

一款简洁美观的智能饮水设备控制应用，支持 iOS 和 Android 平台。

## ✨ 功能特性

- 📱 **手机号登录** - 支持图形验证码 + 短信验证码双重验证
- 📷 **扫码添加设备** - 通过扫描设备二维码快速绑定
- 🔄 **设备切换** - 支持多设备管理，一键切换当前设备
- 💧 **一键出水** - 长按出水，松手停止，操作简单直观
- 🌙 **深色模式** - 自动适配系统深色/浅色模式
- 🎨 **精美 UI** - Material Design 3 设计风格

## 🛠 技术栈

- **Flutter 3.7+** - 跨平台 UI 框架
- **GetX** - 状态管理 & 路由导航
- **Dio** - HTTP 网络请求
- **qr_code_scanner** - 二维码扫描
- **shared_preferences** - 本地数据存储

## 📁 项目结构

```
lib/
├── main.dart                       # 应用入口
├── core/
│   ├── app_controller.dart         # 全局应用控制器
│   ├── models/
│   │   └── device_model.dart       # 设备数据模型
│   ├── services/
│   │   └── drink_api_service.dart  # API服务层
│   └── theme/
│       └── app_theme.dart          # 应用主题配置
└── features/
    ├── login/
    │   ├── login_controller.dart   # 登录控制器
    │   └── login_page.dart         # 登录页面
    ├── home/
    │   ├── home_controller.dart    # 主页控制器
    │   └── home_page.dart          # 主页
    └── scanner/
        └── scanner_page.dart       # 扫码页面
```

## 🚀 快速开始

### 环境要求

- Flutter SDK >= 3.7.0
- Dart SDK >= 3.0.0
- iOS 13.0+ / Android 5.0+

### 安装依赖

```bash
flutter pub get
```

### 运行应用

```bash
# 调试模式
flutter run

# iOS 设备
flutter run -d ios

# Android 设备
flutter run -d android
```

### 构建发布版本

```bash
# 构建 Android APK
flutter build apk --release

# 构建 iOS IPA
flutter build ipa --release --export-method=development
```

## 📡 API 接口

本应用使用惠生活798平台的API接口：

| 接口 | 方法 | 说明 |
|------|------|------|
| `/api/v1/captcha/` | GET | 获取图形验证码 |
| `/api/v1/acc/login/code` | POST | 发送短信验证码 |
| `/api/v1/acc/login` | POST | 登录 |
| `/api/v1/ui/app/master` | GET | 获取设备列表 |
| `/api/v1/dev/favo` | GET | 收藏/切换设备 |
| `/api/v1/dev/start` | GET | 开始出水 |
| `/api/v1/dev/end` | GET | 停止出水 |

## 📦 主要依赖

| 包名 | 用途 |
|------|------|
| get | 状态管理和路由 |
| dio | 网络请求 |
| qr_code_scanner | 二维码扫描 |
| shared_preferences | 本地存储 |
| ionicons | 图标库 |
| google_fonts | 字体 |
| modal_bottom_sheet | 底部弹窗 |

## 📄 License

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！
