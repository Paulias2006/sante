const mongoose = require('mongoose');

const rendezVousSchema = new mongoose.Schema(
  {
    patient: { type: mongoose.Schema.Types.ObjectId, ref: 'Patient', required: true },
    clinique: { type: mongoose.Schema.Types.ObjectId, ref: 'Clinique', required: true },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    date: { type: Date, required: true },
    motif: { type: String, required: true, trim: true },
    status: {
      type: String,
      enum: ['planned', 'confirmed', 'completed', 'cancelled', 'no_show'],
      default: 'planned',
    },
    notes: { type: String, default: '' },
  },
  { timestamps: true }
);

module.exports = mongoose.model('RendezVous', rendezVousSchema);
