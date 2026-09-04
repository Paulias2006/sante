const jwt = require('jsonwebtoken');

function requiredSecret(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`${name} is required`);
  }
  return value;
}

const JWT_SECRET = requiredSecret('JWT_SECRET');
const JWT_REFRESH_SECRET = requiredSecret('JWT_REFRESH_SECRET');
const JWT_QR_SECRET = requiredSecret('JWT_QR_SECRET');

function signAccessToken(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: process.env.JWT_EXPIRY || '15m' });
}

function signRefreshToken(payload) {
  return jwt.sign(payload, JWT_REFRESH_SECRET, { expiresIn: process.env.JWT_REFRESH_EXPIRY || '7d' });
}

function verifyAccessToken(token) {
  return jwt.verify(token, JWT_SECRET);
}

function verifyRefreshToken(token) {
  return jwt.verify(token, JWT_REFRESH_SECRET);
}

function signQrToken(payload, expiresIn = '100y') {
  return jwt.sign(payload, JWT_QR_SECRET, { expiresIn });
}

function verifyQrToken(token) {
  return jwt.verify(token, JWT_QR_SECRET);
}

module.exports = {
  signAccessToken,
  signRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
  signQrToken,
  verifyQrToken,
};
