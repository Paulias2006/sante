const mongoose = require('mongoose');

const consultationSchema = new mongoose.Schema(
  {
    patient: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Patient',
      required: true,
    },
    clinique: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Clinique',
      required: true,
    },
    medecin: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    date: { type: Date, default: Date.now },
    motif: { type: String, required: true },
    diagnostic: { type: String, required: true },
    notes: { type: String, default: '' },
    constantes: {
      tension: { type: String, default: '' },
      temperature: { type: Number, default: null },
      poids: { type: Number, default: null },
      frequenceCardiaque: { type: Number, default: null },
    },
    createdAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

const Consultation = mongoose.model('Consultation', consultationSchema);

module.exports = Consultation;
