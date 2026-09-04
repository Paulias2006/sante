const crypto = require('crypto');

function generateDossierNumber() {
  const random6 = crypto.randomInt(100000, 999999).toString();
  return `ST-${random6}`;
}

module.exports = {
  generateDossierNumber,
};
