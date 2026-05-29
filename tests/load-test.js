import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 50,
  duration: '5m',
};

const ENV = __ENV.TARGET || 'local';

const BASE_URL = ENV === 'cloud' 
  ? 'https://35.205.162.111'
  : 'http://localhost:8000';

export default function () {
  // 1. Login
  const loginRes = http.post(`${BASE_URL}/auth/login`, JSON.stringify({
    username: 'admin',
    password: 'admin123'
  }), {
    headers: { 'Content-Type': 'application/json' }
  });

  check(loginRes, {
    'login bem sucedido': (r) => r.status === 200,
  });

  const token = loginRes.json('access_token');
  if (!token) return;

  const headers = { 'Authorization': `Bearer ${token}` };

  // 2. Upload
  const uploadRes = http.post(`${BASE_URL}/files/upload`, {
    file: http.file('conteudo de teste k6', 'test.txt', 'text/plain')
  }, { headers });

  check(uploadRes, {
    'upload bem sucedido': (r) => r.status === 200,
  });

  const fileId = uploadRes.json('file_id');
  if (!fileId) return;

  // 3. List files
  const listRes = http.get(`${BASE_URL}/files`, { headers });
  check(listRes, {
    'listagem bem sucedida': (r) => r.status === 200,
  });

  // 4. Download
  const downloadRes = http.get(`${BASE_URL}/files/${fileId}`, { headers });
  check(downloadRes, {
    'download bem sucedido': (r) => r.status === 200,
  });

  // 5. Delete
  const deleteRes = http.del(`${BASE_URL}/files/${fileId}`, null, { headers });
  check(deleteRes, {
    'delete bem sucedido': (r) => r.status === 200,
  });

  sleep(1);
}