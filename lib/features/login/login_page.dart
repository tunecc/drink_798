import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/widgets/app_form_fields.dart';
import 'login_controller.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  static const _bandHeight = 168.0;

  @override
  Widget build(BuildContext context) {
    // build 可能被反复调用，控制器只在首次注册时创建。
    final controller = Get.isRegistered<LoginController>()
        ? Get.find<LoginController>()
        : Get.put(LoginController());
    final theme = Theme.of(context);
    final scaffoldColor = theme.scaffoldBackgroundColor;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _bandHeight,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.16),
                    scaffoldColor.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const _LoginHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: _LoginFormPanel(controller: controller),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 顶部标题区，压在渐隐带上，因此颜色必须走主题而不是硬编码白色。
class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.water_drop_rounded,
              color: theme.colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '智能饮水',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  '欢迎使用，让生活更便捷',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 三步流程的面板切换。控制器由参数传入而不是内部 Get.find，
/// widget 测试因此不必依赖服务定位器的注册语义（见 design.md D9）。
class _LoginFormPanel extends StatelessWidget {
  const _LoginFormPanel({required this.controller});

  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isTokenLogin.value) {
        return _TokenForm(controller: controller);
      }
      return controller.isSmsSent.value
          ? _SmsCodeForm(controller: controller)
          : _PhoneForm(controller: controller);
    });
  }
}

class _PhoneForm extends StatelessWidget {
  const _PhoneForm({required this.controller});

  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '登录',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '请输入手机号和图形验证码',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        AppTextField(
          key: const Key('phoneField'),
          controller: controller.phoneController,
          label: '手机号',
          hintText: '请输入手机号',
          keyboardType: TextInputType.phone,
          maxLength: 11,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 16),
        _CaptchaRow(controller: controller),
        const SizedBox(height: 24),
        Obx(
          () => AppPrimaryButton(
            onPressed: controller.sendSmsCode,
            loading: controller.isSendingSms.value,
            child: const Text('获取验证码'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            key: const Key('tokenEntry'),
            onPressed: controller.showTokenLogin,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              textStyle: theme.textTheme.bodySmall,
            ),
            child: const Text('使用已有 Token 登录'),
          ),
        ),
      ],
    );
  }
}

/// 图形验证码：输入框与图片同行，图片高度由输入框约束，点击即换图。
class _CaptchaRow extends StatelessWidget {
  const _CaptchaRow({required this.controller});

  final LoginController controller;

  static const _imageWidth = 104.0;
  static const _imageHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppFieldLabel('图形验证码'),
        const SizedBox(height: AppTextField.labelGap),
        Row(
          // 居中对齐让图片与输入框的中线严格重合（design.md D10），
          // 用 end 对齐时这个结论依赖字体度量，换字体就会悄悄偏移。
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: AppTextField(
                key: const Key('captchaField'),
                controller: controller.captchaController,
                hintText: '请输入验证码',
                keyboardType: TextInputType.number,
                // 官方验证码以 5 位数字为主，这里保留 6 位余量，不做截断。
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.done,
                textAlign: TextAlign.center,
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 4,
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              key: const Key('captchaImage'),
              behavior: HitTestBehavior.opaque,
              onTap: controller.refreshCaptcha,
              child: Container(
                width: _imageWidth,
                height: _imageHeight,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(
                    AppTextField.cornerRadius,
                  ),
                  border: Border.all(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.38,
                    ),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Center(
                      child: Obx(() {
                        final image = controller.captchaImage.value;
                        if (image == null || image.isEmpty) {
                          return const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          );
                        }
                        return Image.memory(image, fit: BoxFit.contain);
                      }),
                    ),
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Icon(
                        Icons.refresh,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SmsCodeForm extends StatelessWidget {
  const _SmsCodeForm({required this.controller});

  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BackButton(
          key: const Key('backFromSms'),
          onPressed: controller.resetToFirstStep,
        ),
        const SizedBox(height: 16),
        Text(
          '输入验证码',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '验证码已发送至 ${controller.phoneController.text}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        AppTextField(
          key: const Key('smsField'),
          controller: controller.smsCodeController,
          label: '短信验证码',
          hintText: '______',
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textInputAction: TextInputAction.done,
          textAlign: TextAlign.center,
          textStyle: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '没有收到？',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TextButton(
              onPressed: controller.resetToFirstStep,
              child: const Text('重新获取'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Obx(
          () => AppPrimaryButton(
            onPressed: controller.login,
            loading: controller.isLoading.value,
            child: const Text('登录'),
          ),
        ),
      ],
    );
  }
}

class _TokenForm extends StatelessWidget {
  const _TokenForm({required this.controller});

  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BackButton(
          key: const Key('backFromToken'),
          onPressed: controller.showPhoneLogin,
        ),
        const SizedBox(height: 16),
        Text(
          'Token 登录',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '粘贴有效的 Token 后即可登录',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        // obscureText 必须在这个 Obx 内读取：面板上层的 Obx 只登记它自己
        // builder 里的取值，子 widget 的 build 读不到，切换会失效。
        Obx(
          () => AppTextField(
            key: const Key('tokenField'),
            controller: controller.tokenController,
            label: 'Token',
            hintText: '请输入或粘贴 Token',
            obscureText: !controller.isTokenVisible.value,
            prefixIcon: Icons.key_rounded,
            suffixIcon: IconButton(
              tooltip: controller.isTokenVisible.value
                  ? '隐藏 Token'
                  : '显示 Token',
              onPressed: controller.isTokenVisible.toggle,
              icon: Icon(
                controller.isTokenVisible.value
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Token 仅保存在本机，用于访问你的饮水设备。',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Obx(
          () => AppPrimaryButton(
            onPressed: controller.loginWithToken,
            loading: controller.isLoading.value,
            child: const Text('验证并登录'),
          ),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        foregroundColor: theme.colorScheme.onSurface,
      ),
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }
}
