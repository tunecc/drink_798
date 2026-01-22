# 💧 智能饮水 (drink_798)

**慧生活798喝水功能的第三方客户端**

因为官方 APP 广告太多、启动慢，所以做了这个简洁版，只保留核心的喝水功能。

## ✨ 功能特性

- 📱 **手机号登录** - 使用惠生活798账号登录
- 📷 **扫码添加设备** - 扫描设备二维码快速绑定
- 🔄 **设备切换** - 支持多设备管理，一键切换
- 💧 **一键出水** - 长按出水，松手停止
- 🌙 **深色模式** - 自动适配系统主题
- 🚀 **无广告** - 简洁纯净，启动飞快

## 📥 下载安装

前往 [Releases](https://github.com/tunecc/drink_798/releases) 页面下载最新版本：

- **iOS**: 下载 `.ipa` 文件（需要自签或越狱安装）
- **Android**: 下载 `.apk` 文件直接安装

## 🛠 技术栈

- **Flutter 3.7+** - 跨平台 UI 框架
- **GetX** - 状态管理 & 路由导航
- **Dio** - HTTP 网络请求
- **qr_code_scanner** - 二维码扫描

## 🚀 自行编译

### 环境要求

- Flutter SDK >= 3.7.0
- Dart SDK >= 3.0.0
- iOS 13.0+ / Android 5.0+

### 编译命令

```bash
# 安装依赖
flutter pub get

# 构建 Android APK
flutter build apk --release

# 构建 iOS IPA
flutter build ipa --release --export-method=development
```

## 📁 项目结构

```
lib/
├── main.dart                       # 应用入口
├── core/
│   ├── app_controller.dart         # 全局控制器
│   ├── models/                     # 数据模型
│   ├── services/                   # API 服务
│   └── theme/                      # 主题配置
└── features/
    ├── login/                      # 登录模块
    ├── home/                       # 主页模块
    └── scanner/                    # 扫码模块
```

## ⚠️ 免责声明

本项目仅供学习交流使用，与惠生活798官方无关。请勿用于商业用途。

## 📄 License

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

**GitHub**: [https://github.com/tunecc/drink_798](https://github.com/tunecc/drink_798)
