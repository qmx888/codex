## Hodexctl 使用说明

`hodexctl` 是一个基于 GitHub Releases assets 与源码 checkout 管理的隔离安装工具，目标是把专用 release 二进制、源码工作区与现有 npm / nvm / 全局 `codex` 分开管理。

### 适用场景

- 你想直接安装上游 release 二进制，而不是源码编译或 npm 包。
- 你希望后续通过固定命令做升级、降级、卸载，而不是每次手动重装。
- 你还希望并行保留一个源码 checkout，用于跟踪 `main`、功能分支、tag 或第三方 fork。
- 你机器上已经有自己的 Node.js / nvm / 全局 `codex`，不想被 `hodex` 覆盖。

### 工作方式

`hodex` 安装时会做三件事：

1. 调用 GitHub Releases API，解析 `latest` 或指定版本的 release。
2. 按当前系统和架构选择匹配的 release asset，并直接下载 `browser_download_url` 指向的最终二进制资产。
3. 把真实二进制放进专用状态目录，再在你选择的命令目录生成 `hodex` 和 `hodexctl` 包装器。

源码模式则会：

1. clone 你指定的 `owner/repo` 或 Git URL。
2. 检查 `git`、Rust 工具链、平台编译工具，以及可选的 `just` / Node。
3. 在确认后自动安装缺失工具，或给出手动安装提示。
4. 切换到指定 branch / tag / commit，并把状态记录到源码条目。
5. 默认使用源码记录名 `codex-source`，也支持自定义名称，但不会接管 `hodex`。

默认状态目录固定为：

- macOS / Linux / WSL: `~/.hodex`
- Windows: `%LOCALAPPDATA%\hodex`

默认目录结构：

```text
~/.hodex/
  bin/
    codex
  libexec/
    hodexctl.sh
  commands/
    hodex
    hodexctl
  state.json
```

Windows 对应为：

```text
%LOCALAPPDATA%\hodex\
  bin\
    codex.exe
  libexec\
    hodexctl.ps1
  commands\
    hodex.cmd
    hodex.ps1
    hodexctl.cmd
    hodexctl.ps1
  state.json
```

命令目录只放包装器，不放真正的 `codex` 二进制。默认情况下，包装器也会集中放在这个专用目录的 `commands` 子目录里，而不是散落到家目录根下的其他位置。

### 支持的平台

| 平台 | 架构 | 说明 |
| --- | --- | --- |
| macOS | x64 / arm64 | 直接匹配对应 Darwin release 资产 |
| Linux | x64 / arm64 | 优先匹配 `legacy-musl`，其次 `musl`，最后回退 `gnu` |
| WSL | x64 / arm64 | 与 Linux 同逻辑 |
| Windows | x64 | 直接匹配 Windows release 资产 |
| Windows | arm64 | 优先匹配 ARM64 资产，缺失时回退 x64 资产并给出提示 |

说明：

- 如果上游某个版本缺少原生 Windows ARM64 资产，`hodexctl.ps1` 会自动回退到 x64 资产。
- 这依赖 Windows ARM 的 x64 仿真层，因此 `list` 里看到的资产名可能是 x64 版本。
- Windows release 安装要求主程序与 `codex-command-runner.exe`、`codex-windows-sandbox-setup.exe` 同时齐全；缺少 helper 时会直接报错，避免落成不完整安装。

### 首次安装

安装时你会被要求在以下命令目录中三选一：

1. `~/.hodex/commands`
2. `~/.hodex/bin`
3. 自定义目录

#### macOS / Linux / WSL

```bash
curl -fsSL https://raw.githubusercontent.com/stellarlinkco/codex/main/scripts/hodexctl/hodexctl.sh -o ./hodexctl.sh
chmod +x ./hodexctl.sh
./hodexctl.sh install
```

也可以独立下载后显式指定目录：

```bash
./hodexctl.sh install \
  --command-dir ~/.hodex/commands \
  --state-dir ~/.hodex \
  --node-mode ask
```

#### Windows PowerShell

```powershell
$script = Join-Path $env:TEMP "hodexctl.ps1"
Invoke-WebRequest https://raw.githubusercontent.com/stellarlinkco/codex/main/scripts/hodexctl/hodexctl.ps1 -OutFile $script
& $script install
```

也可以独立下载后显式指定目录：

```powershell
.\hodexctl.ps1 install `
  -CommandDir $env:LOCALAPPDATA\hodex\commands `
  -StateDir $env:LOCALAPPDATA\hodex `
  -NodeMode ask
```

如果你需要使用自建镜像、本地 HTTP 服务或 CI 假资产做验证，可以设置：

- `HODEX_RELEASE_BASE_URL`
  - 覆盖 release 资产下载根地址。
  - `latest` 会探测 `<base>/latest/download/<asset>`。
  - 指定版本会探测 `<base>/download/<tag>/<asset>`。
- `HODEX_CONTROLLER_URL_BASE`
  - 仅在脚本通过标准输入运行、需要额外同步一份管理脚本副本时生效。
  - 默认值是 `https://raw.githubusercontent.com`。

### 常用命令

安装完成后，后续统一使用 `hodexctl` 管理：

```bash
hodexctl
hodexctl status
hodexctl list
hodexctl upgrade
hodexctl download 1.2.3
hodexctl upgrade 1.2.2
hodexctl downgrade 1.2.1
hodexctl source install --repo stellarlinkco/codex --ref main
hodexctl source switch --profile codex-source --ref feature/my-branch
hodexctl source status
hodexctl relink
hodexctl uninstall
```

补充说明：

- 直接运行 `hodexctl` 时，会显示帮助而不是立即触发安装。
- `hodexctl list` 或 `hodexctl --list` 会列出当前平台可下载的版本。
- macOS / Linux / WSL 下，`install`、`upgrade`、`download`、`status`、`relink`、`uninstall` 这些 release 管理命令支持在没有 `python3`、`jq` 的环境里直接运行。
- `hodexctl list`、版本更新日志页面，以及 `hodexctl source ...` 仍然需要 `python3` 或 `jq` 之一来解析完整 JSON。
- `hodexctl list` 的交互式选择器支持：
  - 每次进入列表默认选中第一项，第一项固定为“源码下载 / 管理”
  - 底部状态栏显示当前选中版本、发布时间和资产信息
  - 上下方向键移动选中项
  - `Enter` 查看该版本更新日志；如果当前选中第一项则进入源码管理菜单
  - `/` 进入实时搜索，只匹配版本号和 release 标题；输入即过滤，`Enter` 确认，`Esc` 取消
  - 单字符这类短查询仍可过滤，但不会做高亮，避免界面过花
  - `n` / `p` 或左右方向键翻页
  - `?` 弹出快捷键帮助
- 在交互式列表里选中版本并回车后，会显示该版本更新日志，并提供二级操作：
  - `Enter` / `Space` 整页向下滚动
  - 上下方向键单行滚动，左右方向键整页滚动
  - `a` 触发 `AI总结`，调用 `hodex`，不可用时自动回退 `codex`，把当前 changelog 总结成中文结果
  - `i` 安装当前选中版本
  - `d` 下载当前平台资产到 `~/downloads`
  - `b` 返回版本列表
  - `q` 退出

Windows 下同时会生成：

- `hodex.cmd`
- `hodex.ps1`
- `hodexctl.cmd`
- `hodexctl.ps1`
所以在 PowerShell、Windows Terminal、常见命令行启动器里都能直接调用。

### 源码下载与同步

`hodexctl` 现在同时支持正式版 release 管理和源码 checkout 管理。规则已经固定：

- `hodex` 只保留给正式版 release
- 源码模式不会接管 `hodex`
- 源码模式不再执行编译，只负责 checkout 与工具链准备

源码模式常见命令：

```bash
hodexctl source install --repo stellarlinkco/codex --ref main
hodexctl source install --git-url git@github.com:someone/codex.git --ref dev --profile codex-fork
hodexctl source update --profile codex-source
hodexctl source switch --profile codex-source --ref feature/new-ui
hodexctl source status
hodexctl source uninstall --profile codex-source
```

行为说明：

- 默认源码记录名为 `codex-source`。
- 源码记录名只需避开保留名称 `hodex`、`hodexctl`、`hodex-stable`。
- Bash 版和 PowerShell 版都会先进入源码下载向导，按步骤确认仓库、源码记录名（`--profile`）、`ref`、`checkout` 目录，再统一确认执行。
- 后续执行 `source status/update/switch/uninstall` 时，如果没有显式传 `--profile` / `-Profile`：
  - 只有一个源码条目时会自动选中它；
  - 有多个源码条目时会优先定位 `codex-source`，否则进入选择器。
- 多个源码条目时，会先进入记录选择器；支持方向键选择的终端会优先使用高亮交互，否则回退到编号选择。
- 执行前会显示“当前值 -> 目标值”差异预览；执行完成后会显示结果摘要页，明确告诉你最终使用了哪个 `checkout` 与 `ref`。
- 下载源码时，会先确认源码 checkout 目录，默认建议 `~/hodex-src/<host>/<owner>/<repo>`，便于在 Finder / IDE 中直接打开。
- 支持 `owner/repo`、HTTPS Git URL、SSH Git URL 三种仓库输入方式。
- 支持在同一工作区切 branch/tag/commit，也支持通过 `--checkout-dir` 使用独立工作区。
- 会检查 `git`、`rustup`、`cargo`、`rustc`、平台开发工具链，以及 `just` / `node` / `npm|pnpm` 等可选项，并支持自动补装。
- 查询 GitHub Releases 时，如果匿名 GitHub API 请求遇到 `403` 限流，`hodexctl` 会优先尝试使用已登录的 `gh api` 兜底；如果 `gh` 不可用、未登录或无仓库访问权限，会给出明确提示。

### Node.js 处理策略

`hodex` 自身不依赖 Node.js 才能运行 release 二进制，但如果检测到系统里没有 Node.js，管理脚本会询问你怎么处理：

- 系统方式安装
  - macOS: Homebrew
  - Linux / WSL: `apt` / `dnf` / `yum` / `pacman` / `zypper`
  - Windows: `winget`
- `nvm`
  - Windows 下对应 `nvm-windows`
- 手动下载安装
- 跳过

注意：

- 这是可选步骤，不会强制安装。
- `uninstall` 默认只删除正式版 release 的状态目录、包装器和 PATH 处理；源码条目需要通过 `hodexctl source uninstall` 单独清理。
- 当最后一个 release / 源码条目都被卸载后，`hodexctl` 包装器和受管 PATH 写入也会一并清理，不会保留坏掉的入口。

### 升级、降级与重建链接

常见操作：

- 升级到最新 release: `hodexctl upgrade`
- 升级到指定 release: `hodexctl upgrade 1.2.2`
- 降级到指定 release: `hodexctl downgrade 1.2.1`
- 重新生成包装器到新的命令目录: `hodexctl relink`
- 更新源码条目: `hodexctl source update --profile codex-source`
- 切换源码条目到新的分支/tag/commit: `hodexctl source switch --profile codex-source --ref main`

如果只是换命令目录，不想重下二进制，优先用 `relink`。如果想切换版本，用 `upgrade` 或 `downgrade`。

### 查看状态

```bash
hodexctl status
```

会显示：

- 当前平台与架构
- 状态目录
- 正式版当前安装版本与 release tag
- 命中的 asset 名称
- 真实二进制路径
- 命令目录
- PATH 处理状态
- Node.js 处理记录
- 当前 `hodex` 指向的运行时别名
- 已安装的源码条目摘要

### 卸载

```bash
hodexctl uninstall
```

默认只清理正式版 release：

- `~/.hodex` 或 `%LOCALAPPDATA%\hodex`
- `hodex` / `hodexctl` 的正式版相关包装器
- `hodexctl` 写入的 PATH 变更（仅当没有源码条目继续使用时）

不会清理：

- Node.js
- nvm / nvm-windows
- npm 全局 `codex`
- 已安装的源码条目
- 你自己安装的其他 release 资产

### 额外选项

#### Shell 版

```bash
./hodexctl.sh install --yes --no-path-update
./hodexctl.sh install --github-token <token>
./hodexctl.sh status --state-dir /custom/state
```

#### PowerShell 版

```powershell
.\hodexctl.ps1 install -Yes -NoPathUpdate
.\hodexctl.ps1 install -GitHubToken <token>
.\hodexctl.ps1 status -StateDir C:\custom\state
```

如果你频繁测试或触发了 GitHub API 限流，建议显式传入 `GitHubToken`。
