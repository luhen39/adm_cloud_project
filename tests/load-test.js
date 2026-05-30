import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';
import { randomIntBetween } from 'https://jslib.k6.io/k6-utils/1.4.0/index.js';

const BASE_URL = 'https://nginx-service';

const uploadTime    = new Trend('upload_time', true);
const downloadTime  = new Trend('download_time', true);
const errorRate     = new Rate('errors');
const uploadCount   = new Counter('uploads');
const downloadCount = new Counter('downloads');

const users = [
  { user: 'admin', pass: 'admin123'  },
  { user: 'user1', pass: 'password1' },
  { user: 'user2', pass: 'password2' },
];

export const options = {
  stages: [
    { duration: '20s', target: 0  },  // baseline
    { duration: '50s', target: 13 },  // 25%
    { duration: '30s', target: 13 },  // mantém 25%
    { duration: '50s', target: 25 },  // 50%
    { duration: '30s', target: 25 },  // mantém 50%
    { duration: '50s', target: 50 },  // 100%
    { duration: '30s', target: 50 },  // mantém 100%
    { duration: '40s', target: 0  },  // desce
    // Total: 300s = 5m00s
  ],
  thresholds: {
    'http_req_duration':                ['p(95)<2000'],
    'http_req_duration{name:upload}':   ['p(95)<3000'],
    'http_req_duration{name:download}': ['p(95)<2000'],
  },
};

export function setup() {
  const tokens    = {};
  const preloaded = {};

  for (const u of users) {
    const loginRes = http.post(
      `${BASE_URL}/auth/login`,
      JSON.stringify({ username: u.user, password: u.pass }),
      { headers: { 'Content-Type': 'application/json' } }
    );
    const token = loginRes.json('access_token');
    if (!token) {
      console.error(`Login falhou para ${u.user}: ${loginRes.status}`);
      continue;
    }
    tokens[u.user] = token;
    console.log(`Token obtido para ${u.user}`);

    preloaded[u.user] = [];
    for (let i = 0; i < 2; i++) {
      const res = http.post(
        `${BASE_URL}/files/upload`,
        { file: http.file('preload content', `preload-${i}.txt`, 'text/plain') },
        { headers: { Authorization: `Bearer ${token}` } }
      );
      if (res.status === 200) {
        preloaded[u.user].push(res.json('file_id'));
        console.log(`Preloaded ficheiro ${i} para ${u.user}`);
      } else {
        console.warn(`Preload ${i} falhou para ${u.user}: ${res.status}`);
      }
    }
  }

  return { tokens, preloaded };
}

export default function ({ tokens, preloaded }) {
  const user  = users[Math.floor(Math.random() * users.length)];
  const token = tokens[user.user];
  if (!token) return;

  const authHeader = `Bearer ${token}`;
  const params     = { headers: { Authorization: authHeader } };

  const roll = Math.random();

  if (roll < 0.40) {
    // --- LIST (40%) ---
    // 503 NÃO conta — rate limit em download é esperado sob carga
    const res = http.get(`${BASE_URL}/files`, {
      ...params,
      tags: { name: 'list' },
    });
    check(res, { 'list 200': r => r.status === 200 });
    errorRate.add(res.status !== 200 && res.status !== 503);

  } else if (roll < 0.80) {
    // --- DOWNLOAD (40%) ---
    // 503 NÃO conta — rate limit em download é esperado sob carga
    const files = preloaded[user.user] || [];
    if (files.length > 0) {
      const fileId = files[Math.floor(Math.random() * files.length)];
      const res = http.get(`${BASE_URL}/files/${fileId}`, {
        ...params,
        tags: { name: 'download' },
      });
      downloadTime.add(res.timings.duration);
      downloadCount.add(1);
      check(res, { 'download 200': r => r.status === 200 });
      errorRate.add(res.status !== 200 && res.status !== 503);
    }

  } else {
    // --- UPLOAD (20%) ---
    // 503 CONTA — demonstra rate limit de 10 req/min a funcionar
    const fileContent = 'x'.repeat(randomIntBetween(100, 5000));
    const res = http.post(
      `${BASE_URL}/files/upload`,
      { file: http.file(fileContent, `test-${Date.now()}.txt`, 'text/plain') },
      { headers: { Authorization: authHeader }, tags: { name: 'upload' } }
    );
    uploadTime.add(res.timings.duration);
    uploadCount.add(1);
    check(res, { 'upload 200': r => r.status === 200 });
    errorRate.add(res.status !== 200); // 503 conta aqui

    if (res.status === 200) {
      const fileId = res.json('file_id');
      if (fileId) {
        http.get(`${BASE_URL}/files/${fileId}/meta`,
          { ...params, tags: { name: 'meta' } });
        http.post(
          `${BASE_URL}/files/${fileId}/share`,
          JSON.stringify({ ttl_seconds: 3600 }),
          { headers: { 'Content-Type': 'application/json', Authorization: authHeader }, tags: { name: 'share' } }
        );
        http.del(`${BASE_URL}/files/${fileId}`, null,
          { ...params, tags: { name: 'delete' } });
      }
    }
  }

  sleep(randomIntBetween(1, 3));
}

export function handleSummary(data) {
  const dur  = data.metrics.http_req_duration?.values || {};
  const reqs = data.metrics.http_reqs?.values         || {};
  const errs = data.metrics.errors?.values            || {};

  const avgLatency = dur.avg      || 0;
  const p95Latency = dur['p(95)'] || 0;
  const rps        = reqs.rate    || 0;
  const errRate    = errs.rate    || 0;
  const littleLaw  = (avgLatency / 1000) * rps;

  console.log('\n=== LEI DE LITTLE ===');
  console.log(`Latência média:             ${avgLatency.toFixed(2)}ms`);
  console.log(`P95 Latência:               ${p95Latency.toFixed(2)}ms`);
  console.log(`Throughput (RPS):           ${rps.toFixed(2)}`);
  console.log(`Erro Rate:                  ${(errRate * 100).toFixed(2)}%`);
  console.log(`Concorrência estimada (N):  ${littleLaw.toFixed(2)} requests`);

  return { 'results.json': JSON.stringify(data, null, 2) };
}