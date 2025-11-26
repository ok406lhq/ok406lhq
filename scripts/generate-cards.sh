
``
#!/usr/bin/env bash
set -euo pipefail

# 可配置项
USERNAME="${USERNAME:-ok406lhq}"
TOKEN="${GH_README_STATS_TOKEN:-}"
REPO_DIR="github-readme-stats"
PORT=4000
IMAGES_DIR="images"
LOGFILE="../../.ghrds.log"

echo "==> Preparing images directory"
mkdir -p "${IMAGES_DIR}"

echo "==> Cloning official github-readme-stats repo (shallow)"
rm -rf "${REPO_DIR}"
git clone --depth 1 https://github.com/anuraghazra/github-readme-stats.git "${REPO_DIR}"

cd "${REPO_DIR}"

echo "==> Installing dependencies (try npm ci, fallback to legacy install). Logs -> ${LOGFILE}"
# 记录安装日志
{
  echo "=== npm version ==="
  node -v || true
  npm -v || true
  echo "=== npm ci start ==="
  npm ci --silent
} > "${LOGFILE}" 2>&1 || {
  echo "npm ci failed, trying npm install --legacy-peer-deps"
  {
    echo "=== npm install --legacy-peer-deps start ==="
    npm install --legacy-peer-deps --silent
  } >> "${LOGFILE}" 2>&1 || {
    echo "Both npm ci and npm install failed. Dumping logs:"
    tail -n 200 "${LOGFILE}" || true
    exit 1
  }
}

echo "==> Building Next.js app (logs -> ${LOGFILE})"
# build 时也把日志记录，以便排查构建报错
{
  GITHUB_TOKEN="${TOKEN}" NODE_ENV=production PORT="${PORT}" npm run build --silent
} >> "${LOGFILE}" 2>&1 || {
  echo "Build failed. Tail of build log:"
  tail -n 300 "${LOGFILE}" || true
  exit 1
}

echo "==> Starting the built app (background). Logs -> ${LOGFILE}"
# 后台启动并把 stdout/stderr 都写入日志
GITHUB_TOKEN="${TOKEN}" NODE_ENV=production PORT="${PORT}" npm start >> "${LOGFILE}" 2>&1 &
PID=$!
echo "Started server with PID ${PID}, logs -> ${LOGFILE}"

# 等待服务启动（最多等待 60 秒）
echo "==> Waiting for server to be ready (max 60s)..."
READY=0
for i in {1..30}; do
  if curl -sSf "http://localhost:${PORT}/api?username=${USERNAME}" > /dev/null 2>&1; then
    READY=1
    echo "Server ready!"
    break
  fi
  sleep 2
done

if [ "${READY}" -ne 1 ]; then
  echo "Error: local server did not start correctly. Dumping last 500 lines of log:"
  tail -n 500 "${LOGFILE}" || true
  kill "${PID}" || true
  exit 1
fi

echo "==> Fetching top-langs SVG"
curl -s "http://localhost:${PORT}/api/top-langs/?username=${USERNAME}&locale=cn" -o "../${IMAGES_DIR}/top-langs.svg" || {
  echo "Failed to fetch top-langs; dumping log:"
  tail -n 200 "${LOGFILE}" || true
  kill "${PID}" || true
  exit 1
}

echo "==> Fetching stats SVG (including private repos)"
curl -s "http://localhost:${PORT}/api?username=${USERNAME}&count_private=true&locale=cn&show_icons=true" -o "../${IMAGES_DIR}/stats.svg" || {
  echo "Failed to fetch stats; dumping log:"
  tail -n 200 "${LOGFILE}" || true
  kill "${PID}" || true
  exit 1
}

echo "==> Stopping local server (PID ${PID})"
kill "${PID}" || true
sleep 1

cd ..
echo "==> Cleaning up cloned repo"
rm -rf "${REPO_DIR}"

echo "==> Done. Generated files:"
ls -l "${IMAGES_DIR}/top-langs.svg" "${IMAGES_DIR}/stats.svg" || true
