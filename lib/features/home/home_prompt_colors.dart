import 'package:flutter/material.dart';

/// 首页提示条的四种底色：警告 / 错误 / 成功，外加一块不带语义的中性底。
///
/// 提示条是一块独立的实底，浅色和深色模式共用同一组值，所以白字只要过一次门槛。
/// 原先直接用 Colors.orange / Colors.red / Colors.green，白色标签压在上面的对比度
/// 分别是 2.16 / 3.68 / 2.78，全部低于 4.5:1。
///
/// [warning] 和 [error] 同时是首页其它元素的语义色（结算按钮、危险操作），
/// 由 home_page.dart 引用，页面和控制器不能各写一份。
abstract final class HomePromptColors {
  static const Color warning = Color(0xFFB45309); // 白字 5.02:1
  static const Color error = Color(0xFFC62828); // 白字 5.62:1
  static const Color success = Color(0xFF2E7D32); // 白字 5.13:1

  /// 中性提示：只是把话说明白，不带警告/错误/成功的语义，色相也不和上面三块撞。
  /// 必须自己声明：不写底色时 GetX 给的是 `Colors.grey.withOpacity(0.2)` 那层
  /// 透明 wash，底不老实；标签颜色又走 `colorText ?? iconColor ?? Colors.black`
  /// 从主题里现取，等于底和墨两头都不由首页说了算。这里把两头一起钉住。
  static const Color notice = Color(0xFF303030); // 白字 13.20:1

  static const Color label = Colors.white;
}
