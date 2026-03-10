## Hodexctl 使用说明

`hodexctl` 用来独立管理 `hodex` 的 release 安装，以及源码下载 / 同步 / 工具链准备；不会覆盖现有 `codex`。

### 固定规则

- `hodex` 只用于 release 版本管理。
- `hodexctl source ...` 只负责源码下载、同步和工具链准备。
- 源码模式不会编译、部署，也不会接管 `hodex`。
- `codex` 原有安装体系不受 `hodexctl` 卸载影响。

### 适用平台

- macOS
- Linux
- WSL
- Windows PowerShell

Linux / WSL 的 release 资产选择顺序为 `musl` -> `gnu`。

### 快速开始

#### macOS / Linux / WSL

```bash
curl -fsSL https://raw.githubusercontent.com/stellarlinkco/codex/main/scripts/install-hodexctl.sh | bash
```

#### Windows PowerShell

```powershell
irm https://raw.githubusercontent.com/stellarlinkco/codex/main/scripts/install-hodexctl.ps1 | iex
```

安装脚本会自动完成 `hodexctl` 自身安装，并提示下一步命令。后续统一使用：

```bash
hodexctl
```

### 安装后立即生效（当前终端）

> `curl | bash` 在子进程里执行，安装脚本无法直接修改你的父终端环境变量（包括 `PATH`）。

- macOS / Linux / WSL:
  - 按安装脚本末尾提示执行 `source ~/.zshrc` / `source ~/.bashrc`（以你的 shell 为准），或直接新开一个终端窗口。
  - 如果你想不依赖 `PATH` 立刻验证，可直接运行命令目录下的包装器：`~/.hodex/commands/hodexctl status`（若自定义了 `--state-dir/--command-dir`，以实际路径为准）。

- Windows PowerShell:
  - `irm ... | iex` 运行在当前会话里，安装脚本会尽量刷新当前会话的 `$env:Path`，通常装完即可直接运行 `hodexctl status`。
  - 如仍未生效：重新打开 PowerShell，或直接运行 `%LOCALAPPDATA%\\hodex\\commands\\hodexctl.cmd status`。

如果你希望手动下载脚本再运行，也可以使用：

```bash
curl -fsSL https://raw.githubusercontent.com/stellarlinkco/codex/main/scripts/hodexctl/hodexctl.sh -o ./hodexctl.sh && chmod +x ./hodexctl.sh && ./hodexctl.sh
```

```powershell
$script = Join-Path $env:TEMP "hodexctl.ps1"; Invoke-WebRequest https://raw.githubusercontent.com/stellarlinkco/codex/main/scripts/hodexctl/hodexctl.ps1 -OutFile $script; & $script
```

### 常用命令

```bash
hodexctl install
hodexctl list
hodexctl upgrade
hodexctl upgrade 1.2.2
hodexctl downgrade 1.2.1
hodexctl download 1.2.2
hodexctl status
hodexctl relink
hodexctl repair
hodexctl uninstall
```

```bash
hodexctl source install --repo stellarlinkco/codex --ref main
hodexctl source update --profile codex-source
hodexctl source switch --profile codex-source --ref feature/my-branch
hodexctl source status
hodexctl source list
hodexctl source uninstall --profile codex-source
```

### 默认位置

- 状态目录：
  - macOS / Linux / WSL: `~/.hodex`
  - Windows: `%LOCALAPPDATA%\hodex`
- 默认源码 checkout 建议放在：`~/hodex-src/<host>/<owner>/<repo>`

### PATH 管理

`hodexctl` 默认会把命令目录写入你的 `PATH`，确保你新开终端即可直接使用 `hodex` / `hodexctl`。

- macOS / Linux / WSL:
  - zsh 会写入 `~/.zprofile` 与 `~/.zshrc`；bash 会写入 `~/.bash_profile` 与 `~/.bashrc`。
  - 写入内容带有标记块，卸载/修复会识别并清理：
    - `# >>> hodexctl >>>` / `# <<< hodexctl <<<`
    - 兼容旧版标记：`# >>> hodex installer >>>` / `# <<< hodex installer <<<`
  - 如你显式使用 `--no-path-update` 或设置 `HODEXCTL_NO_PATH_UPDATE=1`，脚本不会改动 `PATH`，需要你手动加入命令目录。

- Windows PowerShell:
  - 默认写入用户级 `PATH`（注册表 User Path），不会修改系统级 `PATH`。
  - `hodexctl status` 会显示 `PATH 由 hodexctl 管理` 与 `PATH 来源`；卸载只会回滚受管条目，不会误删你原有的 `PATH` 配置。

`hodexctl status` 中的 `PATH 来源` 常见值：

- `managed-profile-block` / `managed-user-path`: 由 `hodexctl` 写入并受管。
- `preexisting-profile` / `preexisting-user-path`: 配置中已存在，不归 `hodexctl` 所有。
- `current-process-only`: 仅当前会话里临时可见（例如你手动 `export PATH=...`）；这种情况 `status` 会提示执行 `hodexctl repair` 以确保持久生效。
- `disabled` / `user-skipped`: 你禁用了自动写入或交互选择跳过。

### 行为说明

- 直接运行 `hodexctl` 会显示帮助。
- `list` 会列出当前平台可下载版本，并支持查看 changelog。
- changelog 页的 `AI总结` 会优先调用本机 `hodex`，不可用时回退到 `codex`。
- GitHub API 匿名请求遇到 `403` 时，会优先尝试 `gh api` 兜底；如果 `gh` 不可用、未登录或无权限，会给出明确提示。
- `relink` 只重建包装器，不重新下载二进制。
- `repair` 用于自愈：修复本地 wrapper / PATH / state 漂移问题；如果正式版二进制缺失，会提示你执行 `hodexctl install` / `hodexctl upgrade` 恢复。

### 查看状态

```bash
hodexctl status
```

状态页会显示当前 release 安装、命令目录、PATH 处理结果，以及已登记的源码条目摘要。

如果你遇到安装/升级后 `hodex` 或 `hodexctl` 命令找不到，优先执行：

```bash
hodexctl status && hodexctl repair
```

```powershell
hodexctl status; hodexctl repair
```

`relink` 与 `repair` 的区别：

- `relink`: 重新生成 `hodex` / `hodexctl` 包装器，并刷新与状态文件相关的链接。
- `repair`: 在 `relink` 基础上做更完整的诊断与自愈（例如识别 `PATH` 只在当前会话生效的情况，并提示/修复）。

### 卸载说明

```bash
hodexctl uninstall
```

- 该命令会卸载受管 release；如果只装了管理器，也会一并清理。
- 源码条目需要通过 `hodexctl source uninstall` 单独清理。
- 当最后一个 release / 源码条目都被移除后，`hodexctl` 包装器和受管 PATH 也会一并清理。

### 常用选项

```bash
hodexctl install --yes --no-path-update
hodexctl install --github-token <token>
hodexctl status --state-dir /custom/state
hodexctl source install --git-url git@github.com:someone/codex.git --profile codex-fork
```

Windows PowerShell 对应参数名为 `-Yes`、`-NoPathUpdate`、`-GitHubToken`、`-StateDir`、`-GitUrl`、`-Profile`。

### 环境变量（高级）

以下环境变量用于定制安装位置、镜像源或行为开关：

- `HODEX_STATE_DIR`: 状态目录（默认 `~/.hodex` / `%LOCALAPPDATA%\hodex`）。
- `HODEX_COMMAND_DIR` / `INSTALL_DIR`: 命令目录（默认 `<state_dir>/commands`）。
- `HODEX_DOWNLOAD_DIR`: 下载目录（`download` 命令使用，默认 `~/Downloads`）。
- `HODEXCTL_REPO` / `CODEX_REPO`: 目标仓库（默认 `stellarlinkco/codex`）。
- `HODEX_CONTROLLER_URL_BASE`: 管理脚本下载 base（用于内网镜像，默认 `https://raw.githubusercontent.com`）。
- `HODEX_RELEASE_BASE_URL`: release 下载 base（用于镜像或测试）。
- `HODEXCTL_NO_PATH_UPDATE=1`: 禁止自动写入 `PATH`。
- `GITHUB_TOKEN`: GitHub API Token（缓解匿名请求速率限制）。
