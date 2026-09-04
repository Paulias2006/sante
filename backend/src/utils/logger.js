const Log = require('../models/Log');

async function logAction({ user, action, patientConcerne, details, ipAddress }) {
  try {
    await Log.create({
      user: user || null,
      action,
      patientConcerne: patientConcerne || null,
      details: details || '',
      ipAddress: ipAddress || '',
      timestamp: new Date(),
    });
  } catch (error) {
    console.error('Log creation failed:', error.message);
  }
}

module.exports = { logAction }; 
