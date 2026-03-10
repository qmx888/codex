#!/usr/bin/env bash
set -euo pipefail

repo="${HODEXCTL_REPO:-${CODEX_REPO:-stellarlinkco/codex}}"
controller_url_base="${HODEX_CONTROLLER_URL_BASE:-https://raw.githubusercontent.com}"
state_dir="${HODEX_STATE_DIR:-$HOME/.hodex}"
command_dir="${HODEX_COMMAND_DIR:-${INSTALL_DIR:-}}"
controller_url="${controller_url_base%/}/${repo}/main/scripts/hodexctl/hodexctl.sh"

select_profile_file() {
  if [[ -n "${SHELL:-}" ]]; then
    case "$SHELL" in
      */zsh)
        printf '%s\n' "$HOME/.zshrc"
        return
        ;;
      */bash)
        printf '%s\n' "$HOME/.bashrc"
        return
        ;;
    esac
  fi

  if [[ -f "$HOME/.zshrc" ]]; then
    printf '%s\n' "$HOME/.zshrc"
  elif [[ -f "$HOME/.bashrc" ]]; then
    printf '%s\n' "$HOME/.bashrc"
  else
    printf '%s\n' "$HOME/.profile"
  fi
}

if ! command -v curl >/dev/null 2>&1; then
  echo "Missing dependency: curl" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
controller_path="$tmp_dir/hodexctl.sh"

printf '==> 下载 hodexctl 管理脚本\n'
curl -fsSL "$controller_url" -o "$controller_path"
chmod +x "$controller_path"
printf '==> 启动 hodexctl 首次安装\n'

args=(manager-install --yes --state-dir "$state_dir" --repo "$repo")

if [[ -n "$command_dir" ]]; then
  args+=(--command-dir "$command_dir")
fi

if [[ "${HODEXCTL_NO_PATH_UPDATE:-0}" == "1" ]]; then
  args+=(--no-path-update)
fi

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  args+=(--github-token "$GITHUB_TOKEN")
fi

"$controller_path" "${args[@]}"

printf '==> 安装完成\n'
effective_command_dir="$state_dir/commands"
if [[ -n "$command_dir" ]]; then
  effective_command_dir="$command_dir"
fi
printf '==> 可直接运行（无需等待 PATH 生效）: %s\n' "$effective_command_dir/hodexctl status"

if [[ "${HODEXCTL_NO_PATH_UPDATE:-0}" != "1" ]]; then
  profile_file="$(select_profile_file)"
  printf '\n'
  printf '==> 为了让当前终端立即可用，请执行:\n'
  printf 'source "%s"\n' "$profile_file"
  printf '\n'
  printf '提示: `curl | bash` 在子进程执行，无法自动刷新父终端的 PATH；新开终端也会自动生效。\n'
fi
