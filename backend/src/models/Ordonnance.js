const mongoose = require('mongoose');

const medicamentSchema = new mongoose.Schema(
  {
    nom: { type: String, required: true },
    dose: { type: String, required: true },
    frequence: { type: String, required: true },
    duree: { type: String, required: true },
    instructions: { type: String, default: '' },
  },
  { _id: false }
);

const ordonnanceSchema = new mongoose.Schema(
  {
    patient: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Patient',
      required: true,
    },
    consultation: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Consultation',
      required: true,
    },
    medecin: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    clinique: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Clinique',
      required: true,
    },
    qrToken: { type: String, required: true, unique: true },
    medicaments: [medicamentSchema],
    instructionsGenerales: { type: String, default: '' },
    status: {
      type: String,
      enum: ['active', 'delivered', 'partial', 'expired'],
      default: 'active',
    },
    validiteJours: { type: Number, enum: [7, 15, 30], required: true },
    renouvelable: { type: Boolean, default: false },
    nombreRenouvellements: { type: Number, default: 0 },
    emiseAt: { type: Date, default: Date.now },
    expireAt: { type: Date, required: true },
  },
  { timestamps: true }
);

const Ordonnance = mongoose.model('Ordonnance', ordonnanceSchema);

module.exports = Ordonnance;
