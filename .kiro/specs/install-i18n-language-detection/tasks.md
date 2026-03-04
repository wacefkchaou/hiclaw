# 实施计划：安装脚本国际化与语言检测

## 概述

为 `hiclaw-install.sh`（Bash）和 `hiclaw-install.ps1`（PowerShell）两个安装脚本增加基于时区的语言自动检测、双语消息系统、语言切换交互、Welcome Message 改造和 `HICLAW_LANGUAGE` 持久化。两个脚本保持一致的逻辑和用户体验。

## 任务

- [x] 1. Bash 脚本：实现语言检测和消息系统基础设施
  - [x] 1.1 在 `install/hiclaw-install.sh` 中实现 `detect_language` 函数和语言优先级逻辑
    - 在时区检测之后添加 `detect_language()` 函数，根据 `HICLAW_TIMEZONE` 映射到 `zh` 或 `en`
    - 中文时区列表：`Asia/Shanghai`、`Asia/Chongqing`、`Asia/Harbin`、`Asia/Urumqi`、`Asia/Taipei`、`Asia/Hong_Kong`、`Asia/Macau`
    - 实现优先级逻辑：环境变量 `HICLAW_LANGUAGE` > `hiclaw-manager.env` 中已有值 > `detect_language()` 推断
    - 在 `HICLAW_TIMEZONE` 检测之后立即调用，设置全局变量 `HICLAW_LANGUAGE`
    - _需求: 1.1, 1.2, 1.3, 1.4_

  - [x] 1.2 在 `install/hiclaw-install.sh` 中实现集中式 `msg` 函数和消息字典
    - 使用 `declare -A MESSAGES` 关联数组存储所有翻译文本，key 格式为 `消息ID.语言代码`
    - 实现 `msg()` 函数，支持 printf 风格参数替换，英文回退机制
    - 定义所有消息 ID 的中英文翻译，包括：安装标题、Onboarding 模式选择、LLM 配置、管理员凭据、端口配置、域名配置、GitHub 集成、数据持久化、工作空间、最终输出面板等
    - _需求: 3.1, 3.2, 3.3, 3.4_

  - [x] 1.3 在 `install/hiclaw-install.sh` 中实现语言切换交互
    - 在 `install_manager` 函数中，Onboarding Mode 选择之前插入语言确认步骤
    - 语言切换提示使用双语显示（因为此时还不确定用户最终选择）
    - 非交互模式（`HICLAW_NON_INTERACTIVE=1`）跳过语言切换提示
    - 默认选项为自动检测的语言，按回车即确认
    - _需求: 2.1, 2.2, 2.3, 2.4_

- [x] 2. Bash 脚本：替换硬编码文本并改造输出
  - [x] 2.1 将 `install/hiclaw-install.sh` 中 `install_manager` 函数的所有硬编码英文文本替换为 `msg` 函数调用
    - 替换安装标题、Registry 信息、Onboarding 模式选择提示
    - 替换 LLM 配置、管理员凭据、端口配置、域名配置等交互提示
    - 替换 GitHub 集成、Skills Registry、数据持久化、工作空间等提示
    - 替换升级/重装/取消选择提示
    - 替换最终输出面板（登录信息、URL、移动端访问等）
    - _需求: 3.1, 3.2, 3.3_

  - [x] 2.2 改造 `install/hiclaw-install.sh` 中的 `send_welcome_message` 函数
    - 在 Welcome Message 中增加 `--- Installation Context ---` 结构化块
    - 包含 `User Language: {HICLAW_LANGUAGE}` 和 `User Timezone: {HICLAW_TIMEZONE}`
    - 修改步骤 2 为明确使用用户选择的语言
    - 增加步骤 3 基于时区推荐更多语言选项
    - 增加步骤 4d 确认语言并提供基于时区的替代选项
    - _需求: 4.1, 4.2, 4.3, 4.4, 4.5_

  - [x] 2.3 在 `install/hiclaw-install.sh` 的 env 文件写入逻辑中增加 `HICLAW_LANGUAGE`
    - 在 `cat > "${ENV_FILE}"` 的 heredoc 中，LLM 配置之前添加 `HICLAW_LANGUAGE` 字段
    - 确保升级安装时从已有 env 文件读取 `HICLAW_LANGUAGE`
    - _需求: 5.1, 5.2, 5.3_

- [x] 3. 检查点 - Bash 脚本完成
  - 确保所有修改语法正确，ask the user if questions arise.

- [x] 4. PowerShell 脚本：实现语言检测和消息系统基础设施
  - [x] 4.1 在 `install/hiclaw-install.ps1` 中实现 `Get-HiClawLanguage` 函数和语言优先级逻辑
    - 在时区检测之后添加 `Get-HiClawLanguage` 函数，使用与 Bash 相同的中文时区列表
    - 实现相同的优先级逻辑：环境变量 > env 文件已有值 > 时区推断
    - 设置 `$script:HICLAW_LANGUAGE` 全局变量
    - _需求: 1.1, 1.2, 1.3, 1.4, 1.5_

  - [x] 4.2 在 `install/hiclaw-install.ps1` 中实现集中式 `Get-Msg` 函数和消息字典
    - 使用 `$script:Messages` 嵌套哈希表存储翻译文本
    - 实现 `Get-Msg` 函数，支持 `-f` 格式化参数替换，英文回退
    - 定义与 Bash 版本一致的所有消息 ID 中英文翻译
    - _需求: 3.1, 3.2, 3.3, 3.4_

  - [x] 4.3 在 `install/hiclaw-install.ps1` 中实现语言切换交互
    - 在 `Install-Manager` 函数中，Onboarding Mode 选择之前插入语言确认步骤
    - 与 Bash 版本相同的双语提示和交互流程
    - 非交互模式跳过语言切换提示
    - _需求: 2.1, 2.2, 2.3, 2.4_

- [x] 5. PowerShell 脚本：替换硬编码文本并改造输出
  - [x] 5.1 将 `install/hiclaw-install.ps1` 中 `Install-Manager` 函数的所有硬编码英文文本替换为 `Get-Msg` 函数调用
    - 替换所有与 Bash 版本对应的交互提示和日志输出
    - _需求: 3.1, 3.2, 3.3_

  - [x] 5.2 改造 `install/hiclaw-install.ps1` 中的 `Send-WelcomeMessage` 函数
    - 与 Bash 版本生成格式一致的 Welcome Message，包含相同的语言和时区字段
    - _需求: 4.1, 4.2, 4.3, 4.4, 4.5_

  - [x] 5.3 在 `install/hiclaw-install.ps1` 的 `New-EnvFile` 函数中增加 `HICLAW_LANGUAGE`
    - 在 env 文件模板中 LLM 配置之前添加 `HICLAW_LANGUAGE` 字段
    - 确保升级安装时从已有 env 文件读取 `HICLAW_LANGUAGE`
    - _需求: 5.1, 5.2, 5.3, 6.4_

- [x] 6. 检查点 - PowerShell 脚本完成
  - 确保所有修改语法正确，两个脚本行为一致，ask the user if questions arise.

- [x] 7. 一致性验证和收尾
  - [x] 7.1 验证两个脚本的时区映射表、消息 ID、Welcome Message 格式完全一致
    - 对比 Bash 和 PowerShell 的中文时区列表
    - 对比两个脚本的消息字典 key 和翻译内容
    - 对比 Welcome Message 模板结构
    - _需求: 6.1, 6.2, 6.3, 6.4_

- [x] 8. 最终检查点 - 确保所有修改完成
  - 确保所有测试通过，两个脚本行为一致，ask the user if questions arise.

## 备注

- 标记 `*` 的任务为可选任务，可跳过以加速 MVP
- 每个任务引用了具体的需求编号以确保可追溯性
- 检查点确保增量验证
- Bash 和 PowerShell 脚本必须保持一致的逻辑和用户体验
