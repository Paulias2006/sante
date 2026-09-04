const mongoose = require('mongoose');

const logSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    action: { type: String, required: true },
    patientConcerne: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Patient',
      default: null,
    },
    details: { type: String, default: '' },
    ipAddress: { type: String, default: '' },
    timestamp: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

const Log = mongoose.model('Log', logSchema);

module.exports = Log;
