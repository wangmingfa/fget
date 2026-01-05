#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# 读取最新 tag
# -----------------------------
latest_tag=$(git tag --list 'v*' --sort=-v:refname | head -n 1)
[[ -z "$latest_tag" ]] && latest_tag="v0.0.0"

version="${latest_tag#v}"
IFS='.' read -r major minor patch <<< "$version"

# -----------------------------
# 菜单数据
# -----------------------------
options=(
  "major  → $((major + 1)).0.0"
  "minor  → $major.$((minor + 1)).0"
  "patch  → $major.$minor.$((patch + 1))"
)

selected=0

# -----------------------------
# 渲染菜单
# -----------------------------
render_menu() {
  clear
  echo "当前最新 tag: $latest_tag"
  echo
  echo "使用 ↑ ↓ 选择版本升级类型，回车确认"
  echo

  for i in "${!options[@]}"; do
    if [[ $i -eq $selected ]]; then
      printf "  \033[1;32m❯ %s\033[0m\n" "${options[$i]}"
    else
      printf "    %s\n" "${options[$i]}"
    fi
  done
}

# -----------------------------
# 读取按键
# -----------------------------
read_key() {
  IFS= read -rsn1 key
  if [[ $key == $'\x1b' ]]; then
    read -rsn2 key
    echo "$key"
  else
    echo "$key"
  fi
}

# -----------------------------
# 交互循环
# -----------------------------
while true; do
  render_menu
  key=$(read_key)

  case "$key" in
    '[A') # ↑
      ((selected--))
      ((selected < 0)) && selected=$((${#options[@]} - 1))
      ;;
    '[B') # ↓
      ((selected++))
      ((selected >= ${#options[@]})) && selected=0
      ;;
    '') # Enter
      break
      ;;
    $'\x03'|$'\x1b') # Ctrl+C / ESC
      echo
      echo "已取消"
      exit 0
      ;;
  esac
done

# -----------------------------
# 计算新版本
# -----------------------------
case "$selected" in
  0)
    major=$((major + 1)); minor=0; patch=0 ;;
  1)
    minor=$((minor + 1)); patch=0 ;;
  2)
    patch=$((patch + 1)) ;;
esac

new_tag="v$major.$minor.$patch"

# -----------------------------
# 确认
# -----------------------------
clear
echo "当前 tag : $latest_tag"
echo "新 tag   : $new_tag"
echo
read -rp "确认创建并推送该 tag？(y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "已取消"
  exit 0
fi

# -----------------------------
# 创建并推送
# -----------------------------
git tag "$new_tag"
git push origin "$new_tag"

echo
echo "✅ 已成功发布 tag: $new_tag"
