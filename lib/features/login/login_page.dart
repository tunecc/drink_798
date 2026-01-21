import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import 'login_controller.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(LoginController());

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF00D4FF),
              Color(0xFF0099CC),
            ],
            stops: [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部标题区域
              _buildHeader(context),
              
              // 主体卡片区域
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Obx(() => controller.isSmsSent.value
                        ? _buildSmsCodeForm(context, controller)
                        : _buildPhoneForm(context, controller)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 顶部标题
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                '智能饮水',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '欢迎使用，让生活更便捷',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  /// 手机号输入表单
  Widget _buildPhoneForm(BuildContext context, LoginController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          '登录',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '请输入手机号和图形验证码',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 32),
        
        // 手机号输入
        _buildInputLabel('手机号', context),
        const SizedBox(height: 8),
        _buildTextField(
          context: context,
          controller: controller.phoneController,
          hintText: '请输入手机号',
          keyboardType: TextInputType.phone,
          maxLength: 11,
          prefixIcon: Icons.phone_android_rounded,
        ),
        const SizedBox(height: 20),
        
        // 图形验证码 - 图片单独一行展示
        _buildInputLabel('图形验证码', context),
        const SizedBox(height: 12),
        
        // 验证码图片 - 大尺寸展示
        GestureDetector(
          onTap: controller.refreshCaptcha,
          child: Container(
            width: double.infinity,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[100],
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[700]!
                    : Colors.grey.shade200,
              ),
            ),
            child: Obx(() {
              final image = controller.captchaImage.value;
              if (image != null && image.isNotEmpty) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    image,
                    fit: BoxFit.contain,
                  ),
                );
              }
              return const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('加载验证码...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: controller.refreshCaptcha,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('看不清？点击刷新'),
          ),
        ),
        const SizedBox(height: 12),
        
        // 验证码输入框
        _buildTextField(
          context: context,
          controller: controller.captchaController,
          hintText: '请输入上方验证码',
          maxLength: 6,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            letterSpacing: 8,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
        ),
        const SizedBox(height: 32),
        
        // 下一步按钮
        SizedBox(
          width: double.infinity,
          height: 56,
          child: Obx(() => FilledButton(
            onPressed: controller.isSendingSms.value
                ? null
                : controller.sendSmsCode,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: controller.isSendingSms.value
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    '获取验证码',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          )),
        ),
      ],
    );
  }

  /// 短信验证码表单
  Widget _buildSmsCodeForm(BuildContext context, LoginController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 返回按钮
        IconButton(
          onPressed: controller.resetToFirstStep,
          icon: const Icon(Icons.arrow_back_rounded),
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[100],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '输入验证码',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '验证码已发送至 ${controller.phoneController.text}',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 40),
        
        // 短信验证码输入
        _buildInputLabel('短信验证码', context),
        const SizedBox(height: 8),
        _buildTextField(
          context: context,
          controller: controller.smsCodeController,
          hintText: '______',
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofocus: true,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black87,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),
        ),
        const SizedBox(height: 16),
        
        // 重新发送
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '没有收到？',
              style: TextStyle(color: Colors.grey[600]),
            ),
            TextButton(
              onPressed: () {
                controller.resetToFirstStep();
              },
              child: const Text('重新获取'),
            ),
          ],
        ),
        const SizedBox(height: 32),
        
        // 登录按钮
        SizedBox(
          width: double.infinity,
          height: 56,
          child: Obx(() => FilledButton(
            onPressed: controller.isLoading.value ? null : controller.login,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: controller.isLoading.value
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    '登录',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          )),
        ),
      ],
    );
  }

  Widget _buildInputLabel(String label, BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black87,
      ),
    );
  }

  /// 通用输入框组件 - 自动适配深色模式
  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    int? maxLength,
    IconData? prefixIcon,
    bool autofocus = false,
    TextAlign textAlign = TextAlign.start,
    TextStyle? style,
    EdgeInsetsGeometry? contentPadding,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      autofocus: autofocus,
      textAlign: textAlign,
      style: style ?? TextStyle(
        fontSize: 16,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          fontSize: style?.fontSize ?? 14,
          letterSpacing: textAlign == TextAlign.center ? 0 : null,
          color: isDark ? Colors.grey[500] : Colors.grey[400],
        ),
        counterText: '',
        prefixIcon: prefixIcon != null 
            ? Icon(prefixIcon, color: isDark ? Colors.grey[400] : Colors.grey[600])
            : null,
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
        contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
      ),
    );
  }
}
