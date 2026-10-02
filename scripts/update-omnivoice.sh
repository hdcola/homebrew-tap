#!/usr/bin/env bash
#
# update-omnivoice.sh
# 检查 OmniVoice 最新 GitHub Release 并更新 Casks/omnivoice.rb
#

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# 路径推导
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CASK_FILE="${REPO_ROOT}/Casks/omnivoice.rb"
UPSTREAM_REPO="hdcola/OmniVoice"

# 参数默认值
TARGET_VERSION=""
COMMIT=false
PUSH=false
FORCE=false
DRY_RUN=false
VERIFY_DOWNLOAD=false

usage() {
  echo -e "${BOLD}用法:${NC}"
  echo -e "  $(basename "$0") [选项] [指定版本]"
  echo ""
  echo -e "${BOLD}描述:${NC}"
  echo -e "  检查 ${UPSTREAM_REPO} 的最新发布版本并自动更新 Casks/omnivoice.rb 中的 version 与 sha256。"
  echo ""
  echo -e "${BOLD}参数:${NC}"
  echo -e "  指定版本               可选，如 0.5.4 或 v0.5.4。若不指定则自动获取 GitHub 最新 Release。"
  echo ""
  echo -e "${BOLD}选项:${NC}"
  echo -e "  -c, --commit          更新后自动执行 git commit"
  echo -e "  -p, --push            提交后推送到远程仓库（自动启用 --commit）"
  echo -e "  -f, --force           即使版本未发生变化，也强制重新计算并更新"
  echo -e "  -n, --dry-run         仅检查版本与计算 sha256，不修改文件"
  echo -e "  --verify-download     始终完整下载 dmg 文件验证 sha256（默认优先使用 GitHub Release 资产摘要）"
  echo -e "  -r, --repo <repo>     指定上游仓库（默认: ${UPSTREAM_REPO}）"
  echo -e "  -h, --help            显示帮助信息"
  echo ""
  echo -e "${BOLD}示例:${NC}"
  echo -e "  $(basename "$0")                     # 检查最新版本并更新本地文件"
  echo -e "  $(basename "$0") -c                  # 检查更新并创建 git commit"
  echo -e "  $(basename "$0") -p                  # 检查更新、commit 并推送到 origin"
  echo -e "  $(basename "$0") -n                  # 预览更新情况（Dry Run）"
  echo -e "  $(basename "$0") 0.5.4               # 指定更新至 0.5.4 版本"
  exit 0
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      ;;
    -c|--commit)
      COMMIT=true
      shift
      ;;
    -p|--push)
      COMMIT=true
      PUSH=true
      shift
      ;;
    -f|--force)
      FORCE=true
      shift
      ;;
    -n|--dry-run)
      DRY_RUN=true
      shift
      ;;
    --verify-download)
      VERIFY_DOWNLOAD=true
      shift
      ;;
    -r|--repo)
      if [[ -z "${2:-}" ]]; then
        err "--repo 需要指定参数"
        exit 1
      fi
      UPSTREAM_REPO="$2"
      shift 2
      ;;
    -*)
      err "未知选项: $1"
      usage
      ;;
    *)
      if [[ -z "$TARGET_VERSION" ]]; then
        TARGET_VERSION="$1"
        shift
      else
        err "多余的参数: $1"
        usage
      fi
      ;;
  esac
done

# 检查必要文件与工具
if [[ ! -f "$CASK_FILE" ]]; then
  err "未找到 Cask 文件: $CASK_FILE"
  exit 1
fi

command -v curl >/dev/null 2>&1 || { err "需要安装 curl"; exit 1; }
command -v shasum >/dev/null 2>&1 || { err "需要安装 shasum"; exit 1; }

# 读取本地当前版本与 sha256
CURRENT_VERSION=$(grep -E '^[[:space:]]*version[[:space:]]+"' "$CASK_FILE" | sed -E 's/.*version[[:space:]]+"([^"]+)".*/\1/')
CURRENT_SHA256=$(grep -E '^[[:space:]]*sha256[[:space:]]+"' "$CASK_FILE" | sed -E 's/.*sha256[[:space:]]+"([^"]+)".*/\1/')

if [[ -z "$CURRENT_VERSION" || -z "$CURRENT_SHA256" ]]; then
  err "无法从 $CASK_FILE 解析当前版本或 sha256"
  exit 1
fi

info "当前 Cask 版本: ${BOLD}${CURRENT_VERSION}${NC} (sha256: ${CURRENT_SHA256:0:12}...)"

# 获取目标版本 Release 信息
RELEASE_JSON=""

if [[ -n "$TARGET_VERSION" ]]; then
  TARGET_TAG="${TARGET_VERSION}"
  [[ "$TARGET_TAG" != v* ]] && TARGET_TAG="v${TARGET_VERSION}"
  TARGET_VERSION="${TARGET_TAG#v}"
  info "正在查询指定版本: ${BOLD}${TARGET_TAG}${NC} ..."

  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    RELEASE_JSON=$(gh release view "$TARGET_TAG" --repo "$UPSTREAM_REPO" --json tagName,name,assets 2>/dev/null || true)
  fi

  if [[ -z "$RELEASE_JSON" ]]; then
    CURL_AUTH=()
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
      CURL_AUTH=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    fi
    RELEASE_JSON=$(curl -fsSL "${CURL_AUTH[@]}" "https://api.github.com/repos/${UPSTREAM_REPO}/releases/tags/${TARGET_TAG}" 2>/dev/null || true)
  fi
else
  info "正在从 GitHub (${UPSTREAM_REPO}) 查询最新发布版本..."

  if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    RELEASE_JSON=$(gh release view --repo "$UPSTREAM_REPO" --json tagName,name,assets 2>/dev/null || true)
  fi

  if [[ -z "$RELEASE_JSON" ]]; then
    CURL_AUTH=()
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
      CURL_AUTH=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    fi
    RELEASE_JSON=$(curl -fsSL "${CURL_AUTH[@]}" "https://api.github.com/repos/${UPSTREAM_REPO}/releases/latest" 2>/dev/null || true)
  fi
fi

if [[ -z "$RELEASE_JSON" ]]; then
  err "获取 Release 信息失败，请检查网络连接、GitHub 仓库地址或 GITHUB_TOKEN"
  exit 1
fi

# 解析 Tag Name
parse_json() {
  local json="$1"
  local expr="$2"
  if command -v jq >/dev/null 2>&1; then
    echo "$json" | jq -r "$expr" 2>/dev/null || true
  else
    # 简单 python 回退
    python3 -c "import sys, json; data=json.loads(sys.argv[1]); exec(sys.argv[2])" "$json" "$expr" 2>/dev/null || true
  fi
}

REMOTE_TAG=""
if command -v jq >/dev/null 2>&1; then
  REMOTE_TAG=$(echo "$RELEASE_JSON" | jq -r '.tagName // .tag_name // empty')
else
  REMOTE_TAG=$(python3 -c "import sys, json; d = json.load(sys.stdin); print(d.get('tagName') or d.get('tag_name') or '')" <<< "$RELEASE_JSON")
fi

if [[ -z "$REMOTE_TAG" ]]; then
  err "无法解析 Release tag 名称"
  exit 1
fi

LATEST_VERSION="${REMOTE_TAG#v}"
info "GitHub 最新版本: ${BOLD}${LATEST_VERSION}${NC} (${REMOTE_TAG})"

# 版本比对
if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]] && [[ "$FORCE" != true ]]; then
  ok "OmniVoice 已经是最新版本 (${BOLD}${CURRENT_VERSION}${NC})，无需更新。"
  info "如需强制重新计算 sha256 并写入，请使用 -f 或 --force 参数。"
  exit 0
fi

# 查找 dmg 资产
DMG_URL=""
DMG_DIGEST=""

if command -v jq >/dev/null 2>&1; then
  DMG_URL=$(echo "$RELEASE_JSON" | jq -r '(.assets[]? | select(.name | endswith(".dmg")) | .url // .browser_download_url) // empty' | head -n 1)
  DMG_DIGEST=$(echo "$RELEASE_JSON" | jq -r '(.assets[]? | select(.name | endswith(".dmg")) | .digest) // empty' | head -n 1)
else
  DMG_URL=$(python3 -c "
import sys, json
d = json.load(sys.stdin)
for a in d.get('assets', []):
    if a.get('name', '').endswith('.dmg'):
        print(a.get('url') or a.get('browser_download_url') or '')
        break
" <<< "$RELEASE_JSON")
  DMG_DIGEST=$(python3 -c "
import sys, json
d = json.load(sys.stdin)
for a in d.get('assets', []):
    if a.get('name', '').endswith('.dmg'):
        print(a.get('digest') or '')
        break
" <<< "$RELEASE_JSON")
fi

# 若资产中没找到 url，则构造标准 github release download 地址
if [[ -z "$DMG_URL" ]] || [[ "$DMG_URL" == *"api.github.com"* ]]; then
  DMG_URL="https://github.com/${UPSTREAM_REPO}/releases/download/v${LATEST_VERSION}/OmniVoice-${LATEST_VERSION}.dmg"
fi

info "DMG 下载地址: ${CYAN}${DMG_URL}${NC}"

NEW_SHA256=""
if [[ "$VERIFY_DOWNLOAD" != true ]] && [[ "$DMG_DIGEST" =~ ^sha256:[0-9a-fA-F]{64}$ ]]; then
  NEW_SHA256="${DMG_DIGEST#sha256:}"
  info "从 Release 资产摘要中直接获取到 sha256: ${GREEN}${NEW_SHA256}${NC}"
else
  info "正在下载 DMG 并计算 sha256..."
  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT
  TMP_FILE="$TMP_DIR/OmniVoice-${LATEST_VERSION}.dmg"

  if curl -fL --progress-bar "$DMG_URL" -o "$TMP_FILE"; then
    NEW_SHA256=$(shasum -a 256 "$TMP_FILE" | awk '{print $1}')
    ok "计算得到 sha256: ${GREEN}${NEW_SHA256}${NC}"
  else
    err "下载 DMG 失败: $DMG_URL"
    exit 1
  fi
fi

if [[ -z "$NEW_SHA256" || ${#NEW_SHA256} -ne 64 ]]; then
  err "无效的 sha256 哈希值: '$NEW_SHA256'"
  exit 1
fi

echo ""
echo -e "${BOLD}更新摘要:${NC}"
echo -e "  版本:   ${RED}${CURRENT_VERSION}${NC}  ==>  ${GREEN}${LATEST_VERSION}${NC}"
echo -e "  SHA256: ${RED}${CURRENT_SHA256:0:16}...${NC}  ==>  ${GREEN}${NEW_SHA256:0:16}...${NC}"
echo ""

if [[ "$DRY_RUN" == true ]]; then
  warn "[Dry-Run] 试运行模式，跳过文件写入与 git 提交。"
  exit 0
fi

# 更新 Casks/omnivoice.rb
sed -i.bak -E \
  -e "s/^([[:space:]]*version[[:space:]]+)\"[^\"]+\"/\1\"${LATEST_VERSION}\"/" \
  -e "s/^([[:space:]]*sha256[[:space:]]+)\"[^\"]+\"/\1\"${NEW_SHA256}\"/" \
  "$CASK_FILE" && rm -f "${CASK_FILE}.bak"

ok "已更新 ${CASK_FILE}"

# 语法与规范校验
if command -v brew >/dev/null 2>&1; then
  info "运行 brew style 检查..."
  if brew style "$CASK_FILE" >/dev/null 2>&1; then
    ok "brew style 检查通过"
  else
    warn "brew style 存在警告或错误，请运行 'brew style ${CASK_FILE}' 查看"
  fi
fi

# Git 提交与推送
if [[ "$COMMIT" == true ]]; then
  cd "$REPO_ROOT"
  if git diff --quiet "$CASK_FILE"; then
    info "Git 工作区无变更，跳过 commit。"
  else
    COMMIT_MSG="chore(omnivoice): bump cask to v${LATEST_VERSION}"
    git add "$CASK_FILE"
    git commit -m "$COMMIT_MSG"
    ok "Git 提交成功: ${BOLD}${COMMIT_MSG}${NC}"

    if [[ "$PUSH" == true ]]; then
      CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
      info "正在推送至 origin/${CURRENT_BRANCH} ..."
      git push origin "$CURRENT_BRANCH"
      ok "推送成功！"
    fi
  fi
else
  info "提示: 可传入 -c/--commit 参数自动创建 git commit，或传入 -p/--push 自动提交并推送。"
fi

ok "更新完成！"
