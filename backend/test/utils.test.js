const test = require('node:test');
const assert = require('node:assert/strict');
const { generateDossierNumber } = require('../src/utils/generateNumber');

process.env.JWT_SECRET = process.env.JWT_SECRET || 'test_access_secret';
process.env.JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'test_refresh_secret';
process.env.JWT_QR_SECRET = process.env.JWT_QR_SECRET || 'test_qr_secret';

const { signQrToken, verifyQrToken } = require('../src/config/jwt');

test('generateDossierNumber returns ST-####### format', () => {
  const value = generateDossierNumber();
  assert.match(value, /^ST-\d{6}$/);
});

test('QR JWT is signed and verified correctly', () => {
  const payload = { patientId: 'abc123', type: 'permanent' };
  const token = signQrToken(payload, '100y');
  const verified = verifyQrToken(token);

  assert.equal(verified.patientId, payload.patientId);
  assert.equal(verified.type, payload.type);
});
