const mongoose = require('mongoose');

const pharmacieSchema = new mongoose.Schema(
  {
    nom: { type: String, required: true, trim: true },
    adresse: { type: String, required: true },
    ville: { type: String, required: true },
    telephone: { type: String, required: true },
    email: { type: String, lowercase: true, trim: true },
    numeroAutorisation: { type: String, required: true, unique: true },
    dateAutorisation: { type: Date },
    responsable: { type: String },
    status: {
      type: String,
      enum: ['pending', 'approved', 'suspended'],
      default: 'pending',
    },
    approvedAt: { type: Date },
    createdAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

const Pharmacie = mongoose.model('Pharmacie', pharmacieSchema);

module.exports = Pharmacie;
