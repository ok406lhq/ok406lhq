#!/usr/bin/env bash
set -euo pipefail

# 可配置
USERNAME="${USERNAME:-ok406lhq}"
TOKEN="${GH_README_STATS_TOKEN:-}"
REPO_DIR="github-readme-stats"
PORT=4000
IMAGES_DIR="images"

echo "==> Preparing images directory"
mkdir -p "${IMAGES_DIR}"

echo "==> Cloning official github-readme-stats repo (shallow)"
git clone --depth 1 https://github.com/anuraghazra/github-readme-stats.git "${REPO_DIR}"

cd "${REPO_DIR}"

echo "==> Installing dependencies (this may take a while)"
# 如果遇到依赖问题，可考虑改用 npm install --legacy-peer-deps
npm ci --silent

echo "==> Building Next.js app"
# GITHUB_TOKEN 用于让服务访问私有仓库
GITHUB_TOKEN="${TOKEN}" NODE_ENV=production PORT="${PORT}" npm run build --silent

echo "==> Starting the built app (background)"
GITHUB_TOKEN="${TOKEN}" NODE_ENV=production PORT="${PORT}" npm start --silent > ../../.ghrds.log 2>&1 &
PID=$!
echo "Started server with PID ${PID}, logs -> .ghrds.log"

# 等待服务启动（最多等待 30 秒）
echo "==> Waiting for server to be ready..."
for i in {1..15}; do
  if curl -sSf "http://localhost:${PORT}/api?username=${USERNAME}" > /dev/null 2>&1; then
    echo "Server ready!"
    break
  fi
  sleep 2
done

# 若仍不可用，输出 log 并退出非零
if ! curl -sSf "http://localhost:${PORT}/api?username=${USERNAME}" > /dev/null 2>&1; then
  echo "Error: local server did not start correctly. Dumping partial logs:"
  tail -n 200 ../../.ghrds.log || true
  kill "${PID}" || true
  exit 1
fi

echo "==> Fetching top-langs SVG"
curl -s "http://localhost:${PORT}/api/top-langs/?username=${USERNAME}&locale=cn" -o "../${IMAGES_DIR}/top-langs.svg"

echo "==> Fetching stats SVG (including private repos)"
curl -s "http://localhost:${PORT}/api?username=${USERNAME}&count_private=true&locale=cn&show_icons=true" -o "../${IMAGES_DIR}/stats.svg"

echo "==> Stopping local server (PID ${PID})"
kill "${PID}" || true

cd ..
echo "==> Cleaning up cloned repo"
rm -rf "${REPO_DIR}"

echo "==> Done. Generated files:"
ls -l "${IMAGES_DIR}/top-langs.svg" "${IMAGES_DIR}/stats.svg" || true
