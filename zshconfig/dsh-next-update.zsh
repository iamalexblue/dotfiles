# ── DSH NEXT 桌面端自动更新 ──────────────────────────────────────────
# dsh update          → 检查并升级到 GitHub 最新版（自动下载/校验/安装/清理旧版）
# dsh update --check  → 只对比当前版本与最新版，不做任何改动
# 其他 dsh 子命令原样透传给 npm 版 dsh CLI。
# 脚本本体：~/dev/dsh-next/install/update.sh
_dsh_next_update_script="$HOME/dev/dsh-next/install/update.sh"
dsh() {
  if [[ $1 == update ]]; then
    shift
    if [[ -f $_dsh_next_update_script ]]; then
      bash $_dsh_next_update_script "$@"
    else
      print -u2 "未找到 DSH NEXT 更新脚本: $_dsh_next_update_script"
      return 1
    fi
  else
    command dsh "$@"
  fi
}
