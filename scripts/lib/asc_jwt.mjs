#!/usr/bin/env node
import crypto from 'node:crypto';
import fs from 'node:fs';

export function createAscJwt({ keyId, issuerId, privateKeyPath }) {
  const privateKey = fs.readFileSync(privateKeyPath, 'utf8');
  const header = base64Url(JSON.stringify({ alg: 'ES256', kid: keyId, typ: 'JWT' }));
  const now = Math.floor(Date.now() / 1000);
  const payload = base64Url(
    JSON.stringify({
      iss: issuerId,
      exp: now + 1200,
      aud: 'appstoreconnect-v1',
    }),
  );
  const data = `${header}.${payload}`;
  const signature = crypto.sign('sha256', Buffer.from(data), {
    key: privateKey,
    dsaEncoding: 'ieee-p1363',
  });
  return `${data}.${base64Url(signature)}`;
}

function base64Url(input) {
  const buffer = Buffer.isBuffer(input) ? input : Buffer.from(input, 'utf8');
  return buffer
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}
