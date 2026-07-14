# 智能饮水 (drink_798)

惠生活798饮水功能的第三方客户端。

这个项目只保留喝水这条流程：登录、选设备、扫码、开始接水、结算。它没有自建后端，直接调用惠生活798现有接口。如果你只是想喝水，不想在官方 App 里翻入口，可以直接用它。

参考项目：[YiQiuYes/schedule](https://github.com/YiQiuYes/schedule)

## 功能特性

- 手机号登录，支持图形验证码和短信验证码
- 登录态本地保存，启动后自动判断是否已登录
- 扫码添加设备，支持收藏设备管理
- 多设备切换，可删除已收藏设备
- 一键开始接水，再次点击结算
- 自动检测设备状态，登录失效时回到登录页
- 跟随系统亮色 / 暗色主题
- 无广告，界面尽量简单

## 下载与安装

发布版本见 [Releases](https://github.com/tunecc/drink_798/releases)。

### Android

下载与你设备 CPU 架构匹配的 `.apk`：

- `arm64-v8a`：大多数 Android 真机，推荐优先下载
- `armeabi-v7a`：较老的 32 位 Android 设备
- `x86_64`：Android 模拟器或少量 x86_64 设备

### iOS

下载 `.ipa` 后要自己签名，或者用现成的 IPA 安装环境。

仓库脚本产出的 `Runner-unsigned.ipa` 没有签名，不能直接装到设备上。

## 使用流程

1. 输入手机号和图形验证码
2. 获取短信验证码并完成登录
3. 扫描设备二维码，或从已收藏设备中选择目标设备
4. 点击“开始接水”
5. 接水完成后点击“结算”

## 项目说明与限制

- 本项目与惠生活798官方无关
- 本项目没有自建后端，直接请求惠生活798现有接口
- 登录 Token 仅保存在本地设备中
- 扫码功能需要相机权限
- 如果官方接口变更、限流或关闭，本项目可能无法继续使用

## 开发与构建

### 环境要求

- Flutter Stable（内置 Dart 3.7 或更高版本）
- JDK 17
- Git
- iOS 13.0+ 设备 / Android 设备或模拟器

说明：

- `qr_code_scanner` 通过 Git 依赖拉取，执行 `flutter pub get` 时本机需要能访问 GitHub
- Android 工程现在还是模板包名 `com.example.drink_water_app`
- iOS 工程现在还是模板 Bundle ID `com.example.drinkWaterApp`
- Android release 构建现在仍用 debug signing；如果要正式分发，先改签名配置
- iOS 构建和导出可安装 IPA 之前，需要先在本机配好 Apple 开发者签名

### 常用命令

```bash
# 安装依赖
flutter pub get

# 本地运行
flutter run

# 静态检查
flutter analyze

# 构建 Android APK 和 iOS 未签名产物
./scripts/build_android_release.sh

# 只构建 Android APK，按 ABI 拆分
./scripts/build_android_release.sh android

# 只构建 iOS 未签名 .app/.ipa
./scripts/build_android_release.sh ios
```

脚本支持 `all`、`android`、`ios` 三种目标；不传参数时默认跑 `all`。

### 构建产物

Android APK 默认输出到：

```text
build/app/outputs/flutter-apk/
```

常见产物包括：

- `app-arm64-v8a-release.apk`
- `app-armeabi-v7a-release.apk`
- `app-x86_64-release.apk`

iOS 未签名产物默认输出到：

```text
build/ios/
build/ios/unsigned-ipa/Runner-unsigned.ipa
```

构建成功后，脚本还会把便于上传 GitHub Release 的文件复制到 `releases/`：

```text
releases/drink_798_v{version}_android_arm64-v8a.apk
releases/drink_798_v{version}_ios_unsigned.ipa
```

其中 `{version}` 来自 `pubspec.yaml` 的版本号（不含 `+build`）。

### iOS 无签名构建提示

`flutter build ios --release --no-codesign` 只表示不做正式签名，不代表构建产物可直接安装。

如果 `flutter build ios --release --no-codesign` 因为 `com.apple.quarantine` 报签名错误，先清掉 Flutter engine cache 的扩展属性再试：

```bash
xattr -dr com.apple.quarantine /你的FlutterSDK/bin/cache/artifacts/engine
```

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

本项目仅供学习和交流，与惠生活798官方无关，请勿用于商业用途。

## License

MIT
