# 需求文档

## 简介

为 HiClaw 的两个安装脚本（`hiclaw-install.sh` 和 `hiclaw-install.ps1`）增加基于用户时区的自动语言检测机制，仅支持中文和英文两种语言。安装脚本在自动识别语言后，允许用户手动切换语言。用户选择的语言和时区信息将传递给 Manager Agent，使其能够以用户选择的语言输出欢迎语，并基于时区信息为用户提供更精确的后续语言选项（如日语、韩语、德语等）。

## 术语表

- **Install_Script**: HiClaw 安装脚本，包括 Bash 版本（`hiclaw-install.sh`）和 PowerShell 版本（`hiclaw-install.ps1`）
- **Language_Detector**: 安装脚本中根据时区自动推断用户默认语言的模块
- **Welcome_Message**: 安装完成后由安装脚本发送给 Manager Agent 的初始化消息，包含用户语言偏好和时区信息
- **Manager_Agent**: HiClaw 系统中的管理者 Agent，负责协调 Worker Agent 并与人类管理员交互
- **User_Language**: 用户选择的界面语言，取值为 `zh`（中文）或 `en`（英文）
- **Timezone**: 用户系统的 IANA 时区标识符（如 `Asia/Shanghai`、`America/New_York`）

## 需求

### 需求 1：基于时区的默认语言自动检测

**用户故事：** 作为安装 HiClaw 的用户，我希望安装脚本能根据我的系统时区自动选择合适的默认语言（中文或英文），以便我能更自然地完成安装过程。

#### 验收标准

1. WHEN Install_Script 启动时，THE Language_Detector SHALL 读取已检测到的系统时区（`HICLAW_TIMEZONE`）并推断默认语言
2. WHILE 时区属于中国大陆（`Asia/Shanghai`、`Asia/Chongqing`、`Asia/Harbin`、`Asia/Urumqi`）、台湾（`Asia/Taipei`）、香港（`Asia/Hong_Kong`）或澳门（`Asia/Macau`）时，THE Language_Detector SHALL 将默认语言设置为 `zh`（中文）
3. WHILE 时区不属于上述中文时区时，THE Language_Detector SHALL 将默认语言设置为 `en`（英文）
4. WHERE 环境变量 `HICLAW_LANGUAGE` 已设置，THE Language_Detector SHALL 使用该环境变量的值作为默认语言，跳过时区推断
5. THE Language_Detector SHALL 在 Bash 脚本（`hiclaw-install.sh`）和 PowerShell 脚本（`hiclaw-install.ps1`）中以相同的逻辑实现

### 需求 2：用户语言切换

**用户故事：** 作为安装 HiClaw 的用户，我希望在安装过程开始前能够确认或切换语言，以便使用我最熟悉的语言完成安装。

#### 验收标准

1. WHEN 语言自动检测完成后，THE Install_Script SHALL 向用户显示当前检测到的语言，并提供切换选项（中文/English）
2. WHEN 用户选择切换语言时，THE Install_Script SHALL 立即将所有后续日志输出和交互提示切换为用户选择的语言
3. WHILE 处于非交互模式（`HICLAW_NON_INTERACTIVE=1`）时，THE Install_Script SHALL 跳过语言切换提示，直接使用自动检测或环境变量指定的语言
4. THE Install_Script SHALL 将语言切换提示作为安装流程的第一个交互步骤，在 Onboarding Mode 选择之前执行

### 需求 3：安装过程的双语日志输出

**用户故事：** 作为安装 HiClaw 的用户，我希望安装过程中的所有提示信息和日志都以我选择的语言显示，以便我能清楚理解每个步骤。

#### 验收标准

1. THE Install_Script SHALL 为所有用户可见的日志消息、提示文本和交互选项提供中文和英文两个版本
2. WHEN 用户选择中文时，THE Install_Script SHALL 使用中文版本输出所有日志消息和交互提示
3. WHEN 用户选择英文时，THE Install_Script SHALL 使用英文版本输出所有日志消息和交互提示（与当前行为一致）
4. THE Install_Script SHALL 通过集中式消息函数（如 `msg` 函数）管理所有可翻译文本，避免在代码中硬编码字符串

### 需求 4：语言和时区信息传递给 Manager Agent

**用户故事：** 作为安装 HiClaw 的用户，我希望我选择的语言和时区信息能传递给 Manager Agent，以便 Manager Agent 用我选择的语言与我交流。

#### 验收标准

1. WHEN 安装完成并发送 Welcome_Message 时，THE Install_Script SHALL 在消息中包含用户选择的语言（`User_Language`）和系统时区（`Timezone`）
2. THE Welcome_Message SHALL 明确指示 Manager_Agent 使用用户选择的语言（`zh` 或 `en`）输出欢迎语
3. THE Welcome_Message SHALL 包含时区信息，以便 Manager_Agent 基于时区推断用户可能使用的其他语言（如日语、韩语、德语等），并在欢迎对话中提供更精确的语言选项
4. WHEN 用户选择中文时，THE Welcome_Message SHALL 指示 Manager_Agent 使用中文进行欢迎对话
5. WHEN 用户选择英文时，THE Welcome_Message SHALL 指示 Manager_Agent 使用英文进行欢迎对话

### 需求 5：环境变量持久化

**用户故事：** 作为安装 HiClaw 的用户，我希望我选择的语言偏好能保存到配置文件中，以便后续升级或重新安装时能记住我的选择。

#### 验收标准

1. WHEN 安装完成时，THE Install_Script SHALL 将用户选择的语言（`HICLAW_LANGUAGE`）写入 `hiclaw-manager.env` 配置文件
2. WHEN 执行升级安装（in-place upgrade）时，THE Install_Script SHALL 从已有的 `hiclaw-manager.env` 中读取 `HICLAW_LANGUAGE` 并使用该值作为默认语言
3. THE Install_Script SHALL 将 `HICLAW_LANGUAGE` 作为环境变量传递给 Manager 容器，以便 Manager_Agent 在后续交互中参考用户的语言偏好

### 需求 6：Bash 和 PowerShell 脚本的一致性

**用户故事：** 作为在不同操作系统上安装 HiClaw 的用户，我希望 Bash 脚本和 PowerShell 脚本提供一致的语言检测和切换体验。

#### 验收标准

1. THE Install_Script（Bash 版本）SHALL 实现与 PowerShell 版本相同的时区到语言的映射规则
2. THE Install_Script（PowerShell 版本）SHALL 实现与 Bash 版本相同的语言切换交互流程
3. THE Install_Script（两个版本）SHALL 生成格式一致的 Welcome_Message，包含相同的语言和时区字段
4. THE Install_Script（两个版本）SHALL 在 `hiclaw-manager.env` 中以相同的格式保存 `HICLAW_LANGUAGE` 变量
