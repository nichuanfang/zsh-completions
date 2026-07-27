---
name: completion-generator
description: >
  补全脚本生成器：当用户提到某个命令没有 zsh tab 补全、想编写补全脚本、或询问如何补全某个命令时，使用此技能。
  触发场景包括：用户在命令后按 tab 没反应、用户说"给 X 写个补全"、"写个 _X 文件"、"为 X 生成 zsh 补全"、
  "X 没有自动补全"、"给 X 添加 tab 补全"，以及任何涉及为命令行工具编写或生成 _arguments _describe 补全的请求。
  对于非名命令（全新、老旧、小众工具），优先使用此技能而非手动编写。
---

# 补全脚本生成器（Completion Script Generator）

为 `zsh-users/zsh-completions` 仓库的命令行工具生成 zsh 补全脚本。

## 工作流程

### 1. 理解命令结构

当用户指定一个命令名（如 `mycli`）时：

1. **运行 `command --help`**（必要时尝试 `command --help-long`、`command -h`）
   - 用 `Bash` 工具运行 `commandname --help` 或 `commandname -h` 获取帮助文本
   
2. **如果命令不在 PATH 中**（或无法直接运行）：
   - 使用 web 搜索查找该命令的文档（参数、子命令、选项）
   - 或使用 context7 查找相关文档
   
3. **如果是已知找不到的命令但有文档**（如 Docker 插件、Homebrew 安装且补全缺失等）：
   - 使用 context7 或 web 搜索查找该命令的官方 `--help` 格式输出

### 2. 分析帮助输出

从 `--help` 输出中提取：

- **子命令列表**：`Available commands:` 或类似标题下的内容
- **全局选项**：所有标记为 `[options]` 的项
- **每个子命令特有的选项**
- **参数类型**：文件路径、URL、枚举值（如 `on|off`）、自由文本等

### 3. 参考现有补全文件

读取用户仓库中的这些文件以了解风格：

- `src/_claude` — 中等复杂度的子命令+选项模式（推荐作为主要参考）
- `src/_age` — 多命令场景（`#compdef` 中有多个命令名）
- `src/_dad` — 简单命令示例

理解这些模式：
- 使用 `_arguments -C`（`-C` 用于子命令分发模式）
- 使用 `'(- *)'{-h,--help}'[description]'` 作为帮助选项约定
- `->state` 用于 `case $state` 分发
- `_describe -t commands 'tag' commands_array` 用于子命令列表
- `1: :->cmds` 表示第一个位置是子命令，`*:: :->args` 表示后续参数

### 4. 生成补全文件

按照以下结构和约定生成文件，写入 `src/_<commandname>`：

```zsh
#compdef <commandname>
# ------------------------------------------------------------------------------
# Description
# -----------
#
#  Completion script for <commandname> <version> (<url>).
#
# ------------------------------------------------------------------------------
# Authors
# -------
#
#  * <Your Name> (<https://github.com/yourname>)
#
# ------------------------------------------------------------------------------

_<commandname>() {
  typeset -A opt_args
  local context state line
  local curcontext="$curcontext"

  local -a commands
  commands=(
    'subcommand:Description of this subcommand'
    'othercmd:Another subcommand description'
  )

  _arguments -C \
    '(- 1 *)'{-h,--help}'[show help message and exit]' \
    '(-v --version)'{-v,--version}'[display version information]' \
    '--verbose[enable verbose output]' \
    '--output=[specify output file]:output file:_files' \
    '1: :->cmds' \
    '*:: :->args' && return 0

  case $state in
    (cmds)
      _describe -t commands '<commandname> command' commands
      ;;
    (args)
      case $words[1] in
        (subcommand)
          _arguments \
            '(-f --flag)'{-f,--flag}'[description of flag]' \
            '*::arguments:_files'
          ;;
        (othercmd)
          _arguments \
            '--option=[description]:option:(choice1 choice2 choice3)'
          ;;
      esac
      ;;
  esac
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

## 补全文件编写规则

### 文件命名与声明

- 文件名：`_<commandname>`，放在 `src/` 目录
- 首行：`#compdef <commandname>`（用空格分隔多个命令名）

### 函数结构与变量声明

```zsh
_<commandname>() {
  typeset -A opt_args
  local context state line
  local curcontext="$curcontext"
  # ... rest of function
}
_<commandname> "$@"
```

### 选项格式约定

```zsh
# 无参数选项
'--option[description of option]'

# 有短格式（同时指定短格式和长格式）：
'--long[description]'
'(-s --short)'{-s,--short}'[description]'

# 唯一的一对（如 (--foo) 表示与自身互斥）：
'(-o --output)'{-o,--output}'[specify output]:message:_files'

# 有互斥选项（互斥的选项名放前面括号里）：
'(-e --encrypt -d --decrypt)'{-e,--encrypt}'[encrypt the input]'

# 带参数选项：
'--output=[description]:output file:_files'
'--mode=[description]:mode:(default advanced expert)'

# 重复选项（\\* 前缀）：
\*'--include=[pattern to include]:pattern:'
```

### 命令分发模式

使用 `_arguments -C`（大写 C）配合 `case $state`：

```zsh
_arguments -C \
  '1: :->cmds' \
  '*:: :->args'

case $state in
  (cmds)
    _describe -t commands '<name> commands' commands_array
    ;;
  (args)
    case $words[1] in
      (subcmd1)
        _arguments '--flag[desc]'
        ;;
      (subcmd2)
        _arguments '--option=[desc]:val:(a b c)'
        ;;
    esac
    ;;
esac
```

不从 `case` 退出时返回非零，规范模式是在每个 `_arguments` 调用后使用 `&& return 0` 或 `&& ret=0`（配合 `local ret=1` 和末尾 `return ret`）。

### 参数完成动作类型

| 动作 | 用法 | 示例 |
|------|------|------|
| `(val1 val2)` | 固定选项列表 | `'1:mode:(debug release)'` |
| `((val\:"desc1" val\:"desc2"))` | 带描述的固定选项 | `'1:mode:((debug\:"Debug mode" release\:"Release mode"))'` |
| `->state` | 转到 case $state | `'1: :->cmds'` |
| `_files` | 文件路径 | `'--file=[input]:input file:_files'` |
| `_files -/` | 仅目录 | `'--dir=[output dir]:directory:_files -/'` |
| `{_values 'tag' a b c}` | 在 action 内调用 | 通过 `{ ... }` 表达式使用 |
| `:message:` | 无补全 | `'1:name:()'` 或仅 `'1:name:'` |

### 描述文本

- 子命令描述使用现在时：`'cmd:Do something'`（`Do` 大写）
- 选项描述：首字母小写（除非是完整句子）：`'--verbose[enable verbose mode]'`
- 描述保持简洁，不超过 60 字符

### 参数编号格式

- `1:` — 第一个必需参数
- `::` — 可选参数
- `*::` — 重复参数

示例：
```zsh
_arguments \
  '1:command:->cmds' \
  '::optional_arg:(a b c)' \
  '*::files:_files'
```

## 输出/保存

- 将生成的文件写入仓库的 `src/_<commandname>` 路径
- 完成后显示文件路径和简短摘要
- 提示用户可以：
  - `unfunction _<commandname> && autoload -U _<commandname>` 来重新加载
  - 或者 `rm -f ~/.zcompdump && compinit` 来重新生成缓存
