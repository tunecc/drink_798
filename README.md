# 智能饮水 (drink_798)

参考项目来自：

1. https://github.com/YiQiuYes/schedule



惠生活798饮水功能的第三方客户端。

这个项目的目标很直接：去掉官方 App 里和喝水无关的内容，只保留登录、选设备、扫码、开始接水、结算这一条核心流程。

## 功能特性

- 手机号登录，支持图形验证码 + 短信验证码
- 登录态本地保存，启动后自动判断是否已登录
- 扫码添加设备，支持收藏设备管理
- 多设备切换，可删除已收藏设备
- 一键开始接水，再次点击结算
- 自动检测设备状态，登录失效时自动回到登录页
- 跟随系统亮色 / 暗色主题
- 无广告，界面尽量保持简洁

## 适用场景

- 你只想用惠生活798的喝水功能
- 你不想在官方 App 里找入口
- 你更在意启动速度和界面简洁度

## 安装

发布版本见 [Releases](https://github.com/tunecc/drink_798/releases)。

- iOS: 下载 `.ipa`，需要自行签名或具备可安装 IPA 的环境
- Android: 下载与你设备 CPU 架构匹配的 `.apk`
- Android `arm64-v8a`: 大多数真机，推荐优先下载
- Android `armeabi-v7a`: 较老的 32 位 Android 设备
- Android `x86_64`: Android 模拟器或少量 x86_64 设备

## 项目说明

- 本项目没有自建后端，直接请求惠生活798现有接口
- 登录 Token 仅保存在本地设备中
- 扫码功能需要相机权限
- 如果官方接口变更、限流或关闭，本项目可能无法继续使用

## 技术栈

- Flutter
- GetX
- Dio
- SharedPreferences
- qr_code_scanner
- google_fonts
- modal_bottom_sheet
- url_launcher

## 自行编译

### 环境要求

- Flutter Stable 版本，且内置 Dart 3.7 或更高版本
- JDK 17
- Git
- iOS 13.0+ / Android 设备或模拟器

说明：

- `qr_code_scanner` 通过 Git 依赖拉取，`flutter pub get` 时需要本机可访问 GitHub
- Android 工程目前仍使用模板包名 `com.example.drink_water_app`
- Android release 构建当前仍使用 debug signing 配置；如果你要正式分发，请先修改签名配置
- iOS 构建和导出 IPA 需要你本地已经配置好 Apple 开发者签名

### 常用命令

```bash
# 安装依赖
flutter pub get

# 本地运行
flutter run

# 静态检查
flutter analyze

# 构建 Android APK + iOS 未签名 .app/.ipa
./scripts/build_android_release.sh

# 只构建 Android APK（按 ABI 拆分）
./scripts/build_android_release.sh android

# 只构建 iOS 未签名 .app/.ipa
./scripts/build_android_release.sh ios

# 等价的 Flutter 原生命令（Android）
flutter build apk --release --split-per-abi

# 等价的 Flutter 原生命令（iOS，无签名）
flutter build ios --release --no-codesign

# 构建已签名 iOS IPA
flutter build ipa --release --export-method=development
```

### Android 发布

- Android 发布默认产出 3 个 APK，位于 `build/app/outputs/flutter-apk/`
- `app-arm64-v8a-release.apk`：大多数真机，优先上传到 Release
- `app-armeabi-v7a-release.apk`：兼容较老的 32 位设备
- `app-x86_64-release.apk`：主要给模拟器或少量 x86_64 设备
- 如果未来改为应用商店分发，优先使用 `flutter build appbundle --release`

### iOS 发布

- `./scripts/build_android_release.sh` 默认也会构建 iOS 未签名产物
- 无签名 iOS 构建使用 `flutter build ios --release --no-codesign`
- 脚本会基于无签名 `Runner.app` 额外打一个 `Runner-unsigned.ipa`
- `Runner.app` 位于 `build/ios/` 下，`Runner-unsigned.ipa` 位于 `build/ios/unsigned-ipa/`
- 如果需要对外分发的 `.ipa`，仍需后续签名并导出

### iOS 无签名打包踩坑记录

- 症状：执行 `flutter build ios --release --no-codesign` 时，Xcode 可能报 `resource fork, Finder information, or similar detritus not allowed`
- 这次排查下来，真正卡住的不是业务代码，也不是证书配置，而是 Flutter 在 `--no-codesign` 场景下仍会对 `Flutter.framework/Flutter` 做一次额外的 ad-hoc 签名
- 如果本机 Flutter SDK 的 iOS engine 缓存带有 macOS 扩展属性，这一步就可能失败。我们这次碰到的是 `com.apple.quarantine` 和 `com.apple.provenance`
- 第一优先级处理方式：清理 Flutter SDK engine 缓存上的扩展属性，然后重试

```bash
xattr -dr com.apple.quarantine /你的FlutterSDK/bin/cache/artifacts/engine
xattr -dr com.apple.provenance /你的FlutterSDK/bin/cache/artifacts/engine
```

- 如果清理扩展属性后仍然失败，可以继续检查 `Flutter.framework/Flutter` 上是否还有残留 `xattr`
- 这次在本机最终采用的兜底方案是：修改本地 Flutter SDK 中 `packages/flutter_tools/lib/src/build_system/targets/ios.dart` 的 `_signFramework`，在没有 codesign identity 时直接跳过这一步
- 这个兜底方案是本机 Flutter SDK 的本地补丁，不属于仓库代码，Flutter 升级后可能会被覆盖
- 结论：`--no-codesign` 只代表不做正式签名，不代表 Flutter 内部一定不会再碰 `codesign`

## 核心流程

1. 输入手机号和图形验证码
2. 获取短信验证码并完成登录
3. 扫描设备二维码，或从已收藏设备中选择目标设备
4. 点击“开始接水”
5. 接水完成后点击“结算”

## 项目结构

```text
lib/
├── main.dart
├── core/
│   ├── app_controller.dart
│   ├── models/
│   ├── services/
│   └── theme/
└── features/
    ├── home/
    ├── login/
    ├── scanner/
    └── splash/
```

## 免责声明

本项目仅供学习和交流使用，与惠生活798官方无关，请勿用于商业用途。

## License

MIT

## 贡献

欢迎提交 Issue 或 Pull Request。

仓库地址：[https://github.com/tunecc/drink_798](https://github.com/tunecc/drink_798)
