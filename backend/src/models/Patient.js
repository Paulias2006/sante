const mongoose = require('mongoose');

const patientSchema = new mongoose.Schema(
  {
    dossierNumber: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },
    qrToken: {
      type: String,
      required: true,
      unique: true,
    },
    nom: { type: String, required: true, trim: true },
    prenom: { type: String, required: true, trim: true },
    dateNaissance: { type: Date, required: true },
    sexe: { type: String, enum: ['M', 'F'], required: true },
    telephone: { type: String, required: true },
    adresse: { type: String, required: true },
    groupeSanguin: {
      type: String,
      enum: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'],
      required: true,
    },
    allergies: [{ type: String, trim: true }],
    carteStatus: {
      type: String,
      enum: ['pending', 'printed', 'delivered'],
      default: 'pending',
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    clinique: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Clinique',
      required: true,
    },
    createdAt: { type: Date, default: Date.now },
    qrRevokedAt: {
      type: Date,
      default: null,
    },
  },
  { timestamps: true }
);

const Patient = mongoose.model('Patient', patientSchema);

module.exports = Patient;
