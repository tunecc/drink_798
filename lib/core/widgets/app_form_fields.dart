import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// 登录页与其它页面共用的表单控件。
///
/// 输入框颜色一律从主题取，深浅色模式无需调用方传参；主按钮则固定
/// 用 [AppTheme.primaryColor]，因为暗色主题下 `filledButtonTheme` 换成
/// `primaryLight` 配白字，对比度会从 2.9:1 掉到 2.2:1。
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.label,
    this.hintText,
    this.keyboardType,
    this.maxLength,
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.autofocus = false,
    this.textInputAction,
    this.textAlign = TextAlign.start,
    this.textStyle,
  });
  final TextEditingController controller;
  final String? label;
  final String? hintText;
  final TextInputType? keyboardType;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool autofocus;
  final TextInputAction? textInputAction;

  /// 验证码一类需要居中大字号的输入框可在此覆盖文本样式。
  final TextStyle? textStyle;

  /// 输入文本与占位符的水平对齐。
  final TextAlign textAlign;

  static const double cornerRadius = 16;

  /// 标签与输入框的间距，页面内所有带标签的字段共用。
  static const double labelGap = 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final outline = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.12);
    final fill = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);
    final resolvedStyle =
        textStyle ??
        theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface);

    final field = TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      autofocus: autofocus,
      textInputAction: textInputAction,
      textAlign: textAlign,
      style: resolvedStyle,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: resolvedStyle?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          // copyWith 会忽略 null 参数，必须显式给 0，否则 hint 会继承
          // 验证码那种大字距，占位符看起来像已输入内容。
          letterSpacing: 0,
        ),
        counterText: '',
        prefixIcon: prefixIcon == null
            ? null
            : Icon(
                prefixIcon,
                color: theme.colorScheme.onSurfaceVariant,
              ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
      ),
    );

    if (label == null) return field;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppFieldLabel(label!),
        const SizedBox(height: labelGap),
        field,
      ],
    );
  }
}

/// 字段标签。需要把标签放在非输入框控件上方时（例如同行的验证码图片）
/// 也用它，避免页面里出现第二份标签样式。
class AppFieldLabel extends StatelessWidget {
  const AppFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}

/// 页面主行动按钮：全宽、固定高度，加载态禁用点击并显示进度指示。
class AppPrimaryButton extends StatelessWidget {
  const AppPrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.loading = false,
    this.height = 56,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          minimumSize: Size(0, height),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTextField.cornerRadius),
          ),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          child: loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : child,
        ),
      ),
    );
  }
}
