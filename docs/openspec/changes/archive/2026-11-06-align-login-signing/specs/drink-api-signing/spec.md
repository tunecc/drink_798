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

### Requirement: 长签名计算

系统 SHALL 保留长签名能力（当前没有接口使用）。长签名 SHALL 在序列化参数之后依次插入时间档位值、token 后 8 个字符、uid 后 8 个字符，再拼接固定密钥片段：`k1[1]`、`k2[25]` 转大写、`k3[0]`、`dF6hJ9kL2nP`、`k4[18]`、`rT8wY1`、`k2[21]`、`G`、`k3[23]`、`iM7oQ`、`k1[15]`、`v`（`k1`–`k4` 为四个固定密钥各自的 MD5 摘要），最后按既有编码规则编码并取 MD5。

时间档位值 SHALL 按 `30 * ((当前毫秒时间戳 + lat - lng) / 30000)` 计算，除法取整。`lat` 与 `lng` 为位置修正值，未提供时 SHALL 取 0。

当 token 长度小于 8 时，token 片段 SHALL 置为空串。当 uid 长度小于 8 时，uid 片段 SHALL 置为空串。

#### Scenario: 长签名包含时间档位

- **WHEN** 在时刻 T 计算长签名
- **THEN** 拼接串中包含 `30 * ((T + lat - lng) / 30000)` 的整数值

#### Scenario: 同一时间档位内签名一致

- **WHEN** 在 30 秒时间窗口内的两个不同时刻，用相同参数、token、uid 计算长签名
- **THEN** 两次签名值相同

#### Scenario: 跨时间档位签名不同

- **WHEN** 在相隔超过 30 秒的两个时刻，用相同参数、token、uid 计算长签名
- **THEN** 两次签名值不同

#### Scenario: token 不足 8 位时置空

- **WHEN** token 长度为 5 个字符
- **THEN** 拼接串中 token 片段为空串，签名仍能正常计算

#### Scenario: uid 不足 8 位时置空

- **WHEN** uid 为空字符串
- **THEN** 拼接串中 uid 片段为空串，签名仍能正常计算

## ADDED Requirements

### Requirement: 签名附加规则

系统 SHALL 只把登录签名以 `sign` 为键追加到 `acc/login` 的查询参数中，追加后保持原有参数不变。其他接口 SHALL NOT 附加签名。

#### Scenario: 登录请求携带签名

- **WHEN** 用户提交手机号与短信验证码登录
- **THEN** 登录请求 URL 的查询参数中包含 `sign` 项

#### Scenario: 设备请求不附加签名

- **WHEN** 系统构造 `dev/start`、`dev/end` 或 `dev/favo` 请求
- **THEN** 请求 URL 的查询参数中不包含 `sign` 项

#### Scenario: 短信验证码请求不附加签名

- **WHEN** 用户请求下发短信验证码
- **THEN** 该请求 URL 的查询参数中不包含 `sign` 项

#### Scenario: 设备状态查询不附加签名

- **WHEN** 系统查询设备在线状态
- **THEN** 请求不包含 `sign` 参数

### Requirement: 接口签名映射

系统 SHALL 只为 `acc/login` 使用登录签名；`acc/login/code`、`dev/start`、`dev/end`、`dev/favo` 与 `ui/app/dev/status` 均不附加签名。

#### Scenario: 登录接口使用登录签名

- **WHEN** 系统构造 `acc/login` 请求
- **THEN** 使用登录签名计算 `sign` 值

#### Scenario: 设备操作接口不附加签名

- **WHEN** 系统构造 `dev/start`、`dev/end` 或 `dev/favo` 请求
- **THEN** 请求不包含 `sign` 参数

#### Scenario: 短信验证码接口不附加签名

- **WHEN** 系统构造 `acc/login/code` 请求
- **THEN** 请求不包含 `sign` 参数

#### Scenario: 设备状态查询不附加签名

- **WHEN** 系统查询设备在线状态
- **THEN** 请求不包含 `sign` 参数

### Requirement: token 登录与设备请求

系统 SHALL 在通过「使用已有 Token 登录」路径登录时，允许用户完成登录并查看设备列表。设备操作请求不附加签名，与该登录路径是否获取 uid 无关。

#### Scenario: token 登录可查看设备列表

- **WHEN** 用户通过粘贴已有 token 完成登录
- **THEN** 用户可以正常看到设备列表

#### Scenario: token 登录后设备操作不附加签名

- **WHEN** 用户通过 token 登录后发起设备操作
- **THEN** 该请求不包含 `sign` 参数，行为与其他登录路径一致
- **AND** 系统不因此崩溃或给出误导性提示

## REMOVED Requirements

### Requirement: 签名附加到请求

**Reason**: 服务端与当前客户端只在 `acc/login` 附加签名，原要求描述的设备接口签名行为不存在。

**Migration**: 改按新增的「签名附加规则」要求。

### Requirement: 接口签名类型映射

**Reason**: 签名类型映射已变化，只有 `acc/login` 使用登录签名。

**Migration**: 改按新增的「接口签名映射」要求。

### Requirement: token 登录路径的限制

**Reason**: 设备操作不再附加签名，原限制（长签名 uid 片段置空）不再成立。

**Migration**: 改按新增的「token 登录与设备请求」要求。

### Requirement: 短签名计算

**Reason**: 登录改用独立的登录签名，短签名不再被任何接口使用，保留该要求会描述不存在的行为。

**Migration**: 登录签名改按「登录请求签名」要求计算；长签名保留为自包含要求，当前没有接口调用。
