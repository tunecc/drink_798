# drink-api-signing Specification

## Purpose
为惠生活798饮水接口提供请求签名能力，使客户端请求能够通过官方服务端的签名校验，恢复开始接水、结算等核心流程。

## Requirements

### Requirement: 参数序列化规则

系统 SHALL 按固定规则把请求参数序列化为签名字符串：参数键按字典序升序排列，每个参数格式化为 `键=值`，各参数以 `&` 连接。布尔值 SHALL 序列化为小写的 `true` 或 `false`。值为空的参数 SHALL 被跳过，不参与序列化。

#### Scenario: 参数按字典序排列

- **WHEN** 请求参数为 `{"did": "123", "upgrade": true, "rcp": false}`
- **THEN** 序列化结果为 `did=123&rcp=false&upgrade=true`

#### Scenario: 布尔值转写为小写字符串

- **WHEN** 参数 `upgrade` 的值为布尔真
- **THEN** 序列化结果中该参数写为 `upgrade=true`，而非 `upgrade=1` 或 `upgrade=True`

#### Scenario: 空值参数被跳过

- **WHEN** 参数表中某个参数的值为空字符串
- **THEN** 该参数不出现在序列化结果中，也不产生多余的 `&` 分隔符

### Requirement: 请求编码规则

系统 SHALL 使用与官方客户端一致的百分号编码规则生成签名输入。该规则 SHALL 放行以下字符不做编码：英文字母、数字，以及 `-`、`.`、`_`、`~`、`!`、`$`、`&`、`'`、`(`、`)`、`*`、`+`、`;`、`=`、`?`、`@`、`/`。其余字符 SHALL 按 UTF-8 字节逐字节编码为 `%XX`。

系统 SHALL NOT 使用 Dart 的 `Uri.encodeQueryComponent` 生成签名输入，因为该函数会把 `=`、`&`、`+`、`;`、`?`、`@`、`/` 一并编码，导致签名值与官方不一致。

#### Scenario: 等号与和号不被编码

- **WHEN** 签名输入包含 `did=123&rcp=false`
- **THEN** 编码结果中 `=` 与 `&` 保持原样，不被转写为 `%3D` 或 `%26`

#### Scenario: 特殊字符按 UTF-8 编码

- **WHEN** 签名输入包含非 ASCII 字符或不在放行集中的字符
- **THEN** 该字符按 UTF-8 字节序列逐字节编码为 `%XX` 形式

#### Scenario: 编码结果与 Dart 标准函数不同

- **WHEN** 对包含 `=` 与 `&` 的字符串分别用本规则和 `Uri.encodeQueryComponent` 编码
- **THEN** 两者结果不同，且本规则的结果中 `=` 与 `&` 保持原样

### Requirement: 密钥派生

系统 SHALL 使用四个固定密钥，分别计算其 MD5 摘要作为签名素材。密钥 SHALL 为 `eZ`、`kzyZ`、`null`、`hn`。四个摘要按序记为 `k1`、`k2`、`k3`、`k4`。

#### Scenario: 四个密钥各自计算摘要

- **WHEN** 系统初始化签名能力
- **THEN** 分别得到 `k1 = MD5("eZ")`、`k2 = MD5("kzyZ")`、`k3 = MD5("null")`、`k4 = MD5("hn")`
- **AND** 每次签名复用同一组摘要，不重复计算

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

### Requirement: 设备启动参数表

系统 SHALL 为 `dev/start` 接口发送六个业务参数：`did`、`upgrade`、`ptype`、`args`、`rcp`、`cnt`。其中 `did` 为设备标识，`upgrade` 为布尔真，`rcp` 为布尔假，`cnt` 为接水次数，`ptype` 为支付类型，`args` 为设备附加参数。

对于饮水设备，`args` SHALL 为空字符串。官方客户端仅在洗衣机、吹风机、触碰开锁三类设备上填充 `args` 的 JSON 内容。

系统 SHALL NOT 再发送 `stype` 参数。

#### Scenario: 开始接水请求包含六个业务参数

- **WHEN** 用户对设备发起开始接水请求
- **THEN** 请求的业务参数包含 `did`、`upgrade`、`ptype`、`args`、`rcp`、`cnt` 六项

#### Scenario: 饮水设备的 args 为空字符串

- **WHEN** 设备为饮水设备
- **THEN** `args` 参数的值为空字符串

#### Scenario: 不再发送 stype 参数

- **WHEN** 系统构造 `dev/start` 请求
- **THEN** 请求不包含 `stype` 参数

#### Scenario: upgrade 与 rcp 的固定取值

- **WHEN** 系统构造 `dev/start` 请求
- **THEN** `upgrade` 为布尔真，`rcp` 为布尔假

### Requirement: 请求头对齐

系统 SHALL 只发送官方客户端使用的请求头：`Authorization`、`VersionCode`、`User-Agent`。系统 SHALL 不再发送 `ApplicationType`、`Accept`、`Accept-Encoding`、`Connection`。

#### Scenario: 已登录请求包含三个头

- **WHEN** 已登录用户发起业务请求
- **THEN** 请求包含 `Authorization`、`VersionCode`、`User-Agent` 三个头

#### Scenario: 未登录请求不包含 Authorization

- **WHEN** 未登录用户发起请求
- **THEN** 请求不包含 `Authorization` 头，但包含 `VersionCode` 与 `User-Agent`

#### Scenario: 废弃的头不再发送

- **WHEN** 系统发起任意业务请求
- **THEN** 请求不包含 `ApplicationType`、`Accept`、`Accept-Encoding`、`Connection` 头

### Requirement: 服务端拒绝时的错误呈现

当服务端因签名无效或其他原因拒绝请求时，系统 SHALL 将该结果与"设备无响应"区分呈现。系统 SHALL NOT 把所有非零返回码一律描述为设备无响应。

#### Scenario: 登录态过期时提示重新登录

- **WHEN** 服务端返回码表示登录状态已过期
- **THEN** 系统提示用户重新登录，而非提示设备无响应

#### Scenario: 其他业务错误码透出

- **WHEN** 服务端返回其他非零业务错误码
- **THEN** 系统呈现服务端返回的错误信息，而非统一提示设备无响应

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
