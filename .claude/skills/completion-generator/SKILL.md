---
name: completion-generator
description: >
  补全脚本生成器：当用户提到某个命令没有 zsh tab 补全、想编写补全脚本、或询问如何补全某个命令时，使用此技能。
  触发场景包括：用户在命令后按 tab 没反应、用户说"给 X 写个补全"、"写个 _X 文件"、"为 X 生成 zsh 补全"、
  "X 没有自动补全"、"给 X 添加 tab 补全"，以及任何涉及为命令行工具编写或生成 _arguments _describe 补全的请求。
  对于非知名命令（全新、老旧、小众工具），优先使用此技能而非手动编写。
---

# 补全脚本生成器（Completion Script Generator）

为 zsh 生成高质量、可直接使用的补全脚本（优先兼容 zsh-users/zsh-completions 风格）。

## 工作流程

### 1. 理解命令结构

当用户指定一个命令名（如 `mycli` 或 `bat`）时：

1. **优先运行帮助命令**
   使用 bash 工具执行 `command --help`、`command -h` 或 `command help`，获取完整帮助文本。

2. **如果命令不在 PATH 中或无法运行**
   - 使用 web_search / open_page 查找官方文档、GitHub README 或 man page。
   - 重点提取：Usage 行、Options、Commands/Subcommands、Arguments。

3. **判断命令类型**（决定采用哪种模板）
   - **A 类（强子命令型）**：有明确的一级子命令列表（如 `git`、`docker`、`kubectl`）。
   - **B 类（选项 + 文件型）**：以大量选项为主，位置参数多为文件/路径，仅有零星可选子命令（如 `bat`、`rg`、`fd`）。
   - **C 类（极简）**：几乎无子命令，仅选项 + 文件。

### 2. 分析帮助输出

从帮助文本中提取：

- 子命令列表及其简短描述
- 全局选项（短/长格式、是否互斥、是否带参数）
- 每个子命令特有的选项
- 位置参数类型（文件、目录、枚举值、自由文本等）
- 特殊行为（`--` 结束选项、可重复选项、环境变量影响等）

### 3. 生成补全文件

#### 推荐控制流模板（必须遵守）

**绝对禁止** 在 `_arguments` 后直接写 `&& return 0` 然后紧跟 `case $state`。
正确写法如下：

```zsh
_<commandname>() {
  local curcontext="$curcontext" ret=1
  local -a state line
  typeset -A opt_args

  _arguments -C \
    # ... 选项与位置参数规格 ...
    '1: :->cmds' \
    '*:: :->args' && ret=0

  case $state in
    (cmds)
      # 补全子命令
      ;;
    (args)
      # 根据 $words[1] 补全子命令参数
      ;;
  esac

  return ret
}
```

对于 **B 类 / C 类**（选项 + 文件为主）的命令，优先采用更简洁的写法，避免不必要的 state 分发：

```zsh
_arguments -S -s \
  # 所有选项 ...
  '*:file:{ _files || compadd <optional-subcommand> }' && ret=0
```

#### 完整推荐模板（强子命令型）

```zsh
#compdef <commandname>
# ------------------------------------------------------------------------------
# Description
# -----------
#
# Completion script for <commandname> (https://...).
#
# ------------------------------------------------------------------------------
# Authors
# -------
#
# * <Your Name> (https://github.com/yourname)
#
# ------------------------------------------------------------------------------

_<commandname>() {
  local curcontext="$curcontext" ret=1
  local -a state line
  typeset -A opt_args

  local -a commands
  commands=(
    'subcommand:Do something useful'
    'othercmd:Do something else'
  )

  _arguments -C \
    '(- *)'{-h,--help}'[show help message and exit]' \
    '(-v --version)'{-v,--version}'[display version information]' \
    '--verbose[enable verbose output]' \
    '--output=[specify output file]:output file:_files' \
    '1: :->cmds' \
    '*:: :->args' && ret=0

  case $state in
    (cmds)
      _describe -t commands '<commandname> commands' commands && ret=0
      ;;
    (args)
      case $words[1] in
        (subcommand)
          _arguments \
            '(-f --flag)'{-f,--flag}'[description of flag]' \
            '*::files:_files' && ret=0
          ;;
        (othercmd)
          _arguments \
            '--option=[description]:option:(choice1 choice2 choice3)' && ret=0
          ;;
      esac
      ;;
  esac

  return ret
}

_<commandname> "$@"

# Local Variables:
# mode: Shell-Script
# sh-indentation: 2
# indent-tabs-mode: nil
# sh-basic-offset: 2
# End:
# vim: ft=zsh sw=2 ts=2 et
```

#### 选项 + 文件型（推荐用于 bat 类工具）的精简写法

```zsh
#compdef bat
# ... header ...

_bat() {
  local curcontext="$curcontext" ret=1
  local -a state line
  typeset -A opt_args

  # 先处理可选子命令
  case $words[2] in
    (cache)
      shift words; (( CURRENT-- ))
      # 调用专门的 cache 补全函数
      _bat_cache && return
      ;;
  esac

  _arguments -S -s \
    # 所有选项规格 ...
    '*: :{ _files || compadd cache }' && ret=0

  # 如有需要动态补全的选项，再处理 state
  case $state in
    (languages) ... ;;
    (themes)    ... ;;
  esac

  return ret
}
```

### 补全文件编写规则（精简版）

- 文件名：`_<commandname>`，放在 `src/` 目录。
- 首行：`#compdef <commandname>`。
- 必须使用 `local ret=1` + 末尾 `return ret`，禁止裸 `&& return 0` 提前退出。
- 选项互斥写在括号内：`'(-a --all -n --none)'{-a,--all}'[...]'`。
- 可重复选项加 `*` 前缀：`\*{-H,--highlight-line=}'[...]'`。
- 文件参数优先使用 `_files`；目录使用 `_files -/`。
- 动态列表（语言、主题等）用 `->state` + `_describe` 或 `_wanted`。
- 描述文本：子命令首字母大写，选项描述首字母小写，尽量 ≤ 60 字符。

### 输出要求

- 将生成的文件写入 `src/_<commandname>`。
- 完成后给出文件路径 + 简短摘要。
- 提示用户重新加载方式：
  ```zsh
  unfunction _<commandname> && autoload -U _<commandname>
  # 或
  rm -f ~/.zcompdump && compinit
  ```

### 额外注意事项

- 生成前务必对照真实 `--help` 输出，避免凭记忆编写过时选项。
- 对于已有官方高质量补全的知名工具（bat、rg、fd、eza 等），优先建议用户使用官方脚本，或在官方基础上做最小增量修改。
- 测试时至少验证：命令后直接 Tab（文件/子命令）、选项后 Tab、带参数选项的值补全。
