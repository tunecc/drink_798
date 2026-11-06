# Spec Delta: drink-api-signing

## ADDED Requirements

### Requirement: 登录请求签名

系统 SHALL 为 `acc/login` 计算登录签名：只取 `authCode` 与 `un` 两个参数，按既有序列化规则得到 `authCode=<短信验证码>&un=<手机号>`，追加固定串 `aB3dF6hJ9kL2nP5rT8wY1eG4iM7oQ0v`，再按既有编码规则编码后取 MD5，输出小写十六进制。

#### Scenario: 固定参数得到固定签名

- **WHEN** 短信验证码为 `123456`、手机号为 `13800138000`
- **THEN** 登录签名等于 `93f9b2ec2c30df3ef4c8b9caeea3013b`

#### Scenario: 签名只覆盖两个参数

- **WHEN** 系统计算登录签名
- **THEN** 参与签名的参数只有 `authCode` 与 `un`，不包含时间、token、uid 或请求头

#### Scenario: 验证码变化导致签名变化

- **WHEN** 同一手机号先后使用两个不同的短信验证码
- **THEN** 两次登录签名不同

### Requirement: 登录请求身份

系统 SHALL 以官方 iOS 客户端的身份发送 `acc/login`：`User-Agent` 为 `iLife798/3.1.9 (iPhone; iOS 17.0; Scale/3.00) iOS_ilife798_3.1.9`，`VersionCode` 为 `3.1.9`，且 SHALL NOT 发送 `ApplicationType`。登录请求体 SHALL 只包含 `authCode` 与 `un`。

#### Scenario: 登录请求头使用 iOS 身份

- **WHEN** 用户提交手机号与短信验证码登录
- **THEN** 请求包含 iOS `User-Agent` 与 `VersionCode: 3.1.9`
- **AND** 请求不包含 `ApplicationType`

#### Scenario: 登录请求体只包含两个参数

- **WHEN** 用户提交登录
- **THEN** 请求体只包含 `authCode` 与 `un`，不包含 `openCode` 或 `cid`

#### Scenario: 其他请求保持原身份

- **WHEN** 已登录用户发起设备或账单请求
- **THEN** 请求仍使用 `Android_ilife798_3.1.8` 身份，不使用登录所用的 iOS 身份

## MODIFIED Requirements

### Requirement: 签名附加到请求

系统 SHALL 把签名值以 `sign` 为键追加到请求的查询参数中。追加后 SHALL 保持原有参数不变，仅新增 `sign` 一项。`acc/login/code` SHALL NOT 附加签名。

#### Scenario: 开始接水请求携带签名

- **WHEN** 用户对设备发起开始接水请求
- **THEN** 请求 URL 的查询参数中除六个业务参数外，还包含 `sign` 项
- **AND** 六个业务参数的值在追加签名后未被修改

#### Scenario: 结算请求携带签名

- **WHEN** 用户对设备发起结算请求
- **THEN** 请求 URL 的查询参数中包含 `sign` 项

#### Scenario: 收藏设备请求携带签名

- **WHEN** 用户收藏或取消收藏设备
- **THEN** 请求 URL 的查询参数中包含 `sign` 项

#### Scenario: 登录请求携带签名

- **WHEN** 用户提交手机号与短信验证码登录
- **THEN** 登录请求 URL 的查询参数中包含 `sign` 项

#### Scenario: 短信验证码请求不附加签名

- **WHEN** 用户请求下发短信验证码
- **THEN** 该请求 URL 的查询参数中不包含 `sign` 项

### Requirement: 接口签名类型映射

系统 SHALL 为每个接口指定正确的签名类型：`dev/start`、`dev/end`、`dev/favo` 使用长签名；`acc/login` 使用登录签名；`acc/login/code` 与 `ui/app/dev/status` 不附加签名。

#### Scenario: 设备操作接口使用长签名

- **WHEN** 系统构造 `dev/start` 或 `dev/end` 请求
- **THEN** 使用长签名计算 `sign` 值

#### Scenario: 登录接口使用登录签名

- **WHEN** 系统构造 `acc/login` 请求
- **THEN** 使用登录签名计算 `sign` 值

#### Scenario: 短信验证码接口不附加签名

- **WHEN** 系统构造 `acc/login/code` 请求
- **THEN** 请求不包含 `sign` 参数

#### Scenario: 设备状态查询不附加签名

- **WHEN** 系统查询设备在线状态
- **THEN** 请求不包含 `sign` 参数

## REMOVED Requirements

### Requirement: 短签名计算

**Reason**: 登录改用独立的登录签名，短签名不再被任何接口使用，保留该要求会描述不存在的行为。

**Migration**: 登录签名改按「登录请求签名」要求计算；设备接口仍按「长签名计算」要求计算。
