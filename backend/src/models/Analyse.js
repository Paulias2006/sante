const mongoose = require('mongoose');

const resultatSchema = new mongoose.Schema(
  {
    parametre: { type: String, required: true },
    valeur: { type: String, required: true },
    unite: { type: String, default: '' },
    statut: {
      type: String,
      enum: ['normal', 'bas', 'eleve', 'critique'],
      default: 'normal',
    },
  },
  { _id: false }
);

const analyseSchema = new mongoose.Schema(
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
    type: { type: String, required: true },
    resultats: [resultatSchema],
    date: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

const Analyse = mongoose.model('Analyse', analyseSchema);

module.exports = Analyse;
