# Brainstorm Summary

- Change: align-login-signing
- Date: 2026-11-05

## 确认的技术方案

登录请求改为携带官方签名，并使用服务端校验的客户端身份：

- `DrinkApiSigner.loginSign(params) = MD5(objcEncode(serialize(params) + LOGIN_SALT))`，`LOGIN_SALT = aB3dF6hJ9kL2nP5rT8wY1eG4iM7oQ0v`
- 登录签名只覆盖 `authCode` 与 `un`；登录 body 只发送这两项
- 登录请求单独使用 iOS 身份（`User-Agent: iLife798/3.1.9 (iPhone; iOS 17.0; Scale/3.00) iOS_ilife798_3.1.9`、`VersionCode: 3.1.9`、无 `ApplicationType`），通过 per-request `Options` 注入
- 全局 Dio 头（`Android_ilife798_3.1.8`）与设备长签名保持不动
- 删除已无调用方的 `shortSign` 及其规格要求

## 关键取舍与风险

- 采用已验证的 iOS 身份而非未验证的 Android 盐值；token 不绑定 UA 已由同网关的兄弟客户端实测
- 新增独立常量而不改密钥派生，避免静默改变设备签名盐值
- 风险：协议常量轮换（由签名向量测试暴露）、混合身份（降级方案为改回 Android 身份并验证盐值）

## 测试策略

- `loginSign` 固定向量 `93f9b2ec2c30df3ef4c8b9caeea3013b`（`authCode=123456`、`un=13800138000`）
- mock adapter 断言登录 URL 的 `sign`、两个请求头、无 `ApplicationType`、body 仅两项
- 非登录请求断言仍携带 `VersionCode: 3.1.8` 与 Android UA
- 用新登录 token 在真实服务端核对 `/acc/score/acc-score` 与账单读取

## Spec Patch

无（Open 阶段的 delta spec 已覆盖：新增「登录请求签名」「登录请求身份」，修改「签名附加到请求」「接口签名类型映射」，删除「短签名计算」）
