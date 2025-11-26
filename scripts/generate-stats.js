// Node 脚本：拉取仓库信息并生成简易 SVG（在 GitHub Actions runner 上运行）
// 需要在仓库 Secrets 中设置 GH_README_STATS_TOKEN（用于读取私有仓库数据）
const fs = require('fs');
const token = process.env.GH_README_STATS_TOKEN || '';
const username = process.env.USERNAME || 'ok406lhq';

async function fetchJSON(url) {
  const headers = { 'User-Agent': 'github-stats-generator' };
  if (token) headers['Authorization'] = `token ${token}`;
  const res = await fetch(url, { headers });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`HTTP ${res.status} ${res.statusText} for ${url}\n${text}`);
  }
  return res.json();
}

async function fetchAllRepos() {
  let page = 1;
  const per_page = 100;
  const all = [];
  // 如果提供 token，使用 /user/repos（可包括私有仓库）
  const useUserEndpoint = !!token;
  while (true) {
    const url = useUserEndpoint
      ? `https://api.github.com/user/repos?per_page=${per_page}&page=${page}&affiliation=owner`
      : `https://api.github.com/users/${username}/repos?per_page=${per_page}&page=${page}`;
    const data = await fetchJSON(url);
    if (!Array.isArray(data) || data.length === 0) break;
    all.push(...data);
    if (data.length < per_page) break;
    page++;
  }
  return all;
}

function renderSVG(stats) {
  const { username, totalRepos, privateCount, stars, forks, followers } = stats;
  const w = 460, h = 140;
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" xmlns="http://www.w3.org/2000/svg">
  <style>
    .title{font:700 18px system-ui; fill:#0f172a;}
    .label{font:600 12px system-ui; fill:#334155;}
    .value{font:700 20px system-ui; fill:#0f172a;}
    .small{font:400 11px system-ui; fill:#475569;}
  </style>
  <rect rx="10" width="100%" height="100%" fill="#f8fafc"/>
  <g transform="translate(20,20)">
    <text class="title">${username} · GitHub Stats</text>
    <g transform="translate(0,28)">
      <text class="label">Repositories</text>
      <text class="value" x="180">${totalRepos}</text>
      <text class="small" x="260">private: ${privateCount}</text>
    </g>
    <g transform="translate(0,62)">
      <text class="label">Stars</text>
      <text class="value" x="180">${stars}</text>
      <text class="label" x="260">Forks</text>
      <text class="value" x="330">${forks}</text>
    </g>
    <g transform="translate(0,96)">
      <text class="label">Followers</text>
      <text class="value" x="180">${followers}</text>
    </g>
  </g>
</svg>`;
}

(async () => {
  try {
    const repos = await fetchAllRepos();
    const stats = {
      username,
      totalRepos: repos.length,
      privateCount: repos.filter(r => r.private).length,
      stars: repos.reduce((s, r) => s + (r.stargazers_count || 0), 0),
      forks: repos.reduce((s, r) => s + (r.forks_count || 0), 0),
      followers: 0
    };
    try {
      const userUrl = token ? 'https://api.github.com/user' : `https://api.github.com/users/${username}`;
      const user = await fetchJSON(userUrl);
      stats.followers = user.followers || 0;
    } catch (e) {
      // 可忽略 followers 获取失败的情况
    }
    const svg = renderSVG(stats);
    fs.writeFileSync('images/stats.svg', svg, 'utf8');
    console.log('Saved images/stats.svg');
  } catch (err) {
    console.error('Error generating stats:', err.message);
    process.exit(1);
  }
})();
