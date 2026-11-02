/// 账户余额：钱包余额（元）与可用积分。
///
/// 两个字段都可空：对应接口失败时该侧为 null，UI 据此隐藏对应值。
class AccountBalance {
  const AccountBalance({this.walletYuan, this.score});

  final double? walletYuan;
  final int? score;
}
