# `codex github` webhook 运行说明

`codex github` 会在本地启动一个 GitHub webhook HTTP 服务，用来把 GitHub issue / pull request 的 `/codex ...` 指令转发给本地 Codex。

## 触发面

当前支持的 GitHub 事件：

- `issue_comment`
- `pull_request_review_comment`
- `pull_request_review`

只有评论或 review body 里出现配置好的命令前缀（默认是 `/codex`）时，才会创建 work item。

## 必需环境变量

默认读取以下环境变量：

- `GITHUB_WEBHOOK_SECRET`：GitHub webhook secret，用来校验 `X-Hub-Signature-256`
- `GITHUB_TOKEN`：用于 GitHub REST API 和 clone/fetch 的 token

`GITHUB_TOKEN` 需要同时满足两件事：

1. 能访问目标仓库的协作者/权限 API
2. 能 clone / fetch 目标仓库

如果你走 `gh repo clone`，也要确保本机 `gh auth status` 正常，或让 `GITHUB_TOKEN` / `GH_TOKEN` 对 `gh` 可见。

## GitHub 侧怎么配

### 仓库 Webhook

Payload URL 填你暴露出去的地址，例如：

- `https://example.ngrok.app/`

Content type 选：

- `application/json`

Secret 填与你本地 `GITHUB_WEBHOOK_SECRET` 一致的值。

勾选事件：

- `Issue comments`
- `Pull request reviews`
- `Pull request review comments`

### GitHub App

GitHub App 的 webhook URL / Callback URL 也填同一个公网地址：

- `https://example.ngrok.app/`

注意：

- Webhook URL 是事件投递地址
- 不是 OAuth callback 流程时，也可以和 Callback URL 保持一致
- 安装到用户/组织后，只有被安装覆盖到的仓库才会投递 webhook

## 本地目录布局

仓库缓存和工作目录都放在 `CODEX_HOME` 下：

- repo cache：`~/.codex/github-repos/<owner>/<repo>/repo`
- issue worktree：`~/.codex/github-repos/<owner>/<repo>/issues/<number>`
- pull worktree：`~/.codex/github-repos/<owner>/<repo>/pulls/<number>`
- thread state：`~/.codex/github/threads/<owner>/<repo>/...`
- delivery markers：`~/.codex/github/deliveries/*.marker`

同一个仓库 + 同一个 issue / pull number 只会复用同一个 worktree。

## 运行时行为

收到有效 webhook 后，`codex github` 会：

1. 校验 HMAC 签名
2. 校验 repo allowlist（如果配置了 `--allow-repo`）
3. 校验 sender 是否满足最小仓库权限要求
4. clone / fetch 仓库并准备 issue / pull worktree
5. 拉取 GitHub 上下文并写入 `.codex_github_context.md`
6. 在对应 worktree 里运行 Codex
7. 将结果回贴到 issue comment / review comment / review

## 清理与存储

当前实现遵循“先保守、后回收”的原则：

- delivery markers 默认 `7` 天 TTL
- repo cache 默认不自动删除（`--repo-ttl-days 0`）
- repo cache 只有在 `issues/` 和 `pulls/` 都为空时才会被 GC

这意味着：

- repo cache 是缓存，不是源数据
- worktree 如果长期累积，会占用磁盘
- 想启用 repo cache GC，先要保证对应 worktree 已经被清空

推荐运维策略：

- 常驻服务：开启 `--delivery-ttl-days 7`
- 磁盘紧张：配合外部定时任务清理不再使用的 `issues/` / `pulls/` worktree
- 高安全环境：显式设置更高的 `--min-permission`

## 常见问题

### `401 bad signature`

通常是：

- GitHub 侧 secret 和本地 `GITHUB_WEBHOOK_SECRET` 不一致
- 反向代理改写了 body

### `permission check failed`

通常是：

- `GITHUB_TOKEN` 不能调用 repo permission API
- token 没有覆盖到组织仓库
- token 能评论但不能读协作者权限

### `git clone failed`

通常是：

- `GITHUB_TOKEN` 无法 clone 该仓库
- 本机 `gh` 未登录或登录到错误账号
- 内网环境没有把 `github.com` 网络打通

## 推荐启动方式

```bash
export GITHUB_WEBHOOK_SECRET=your-secret
export GITHUB_TOKEN=your-token
codex github --listen 127.0.0.1:8787
```

如果你要只允许某个仓库触发：

```bash
codex github --allow-repo owner/repo
```
