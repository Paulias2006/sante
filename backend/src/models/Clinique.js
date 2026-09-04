const mongoose = require('mongoose');

const cliniqueSchema = new mongoose.Schema(
  {
    nom: { type: String, required: true, trim: true },
    type: {
      type: String,
      enum: ['clinique_privee', 'hopital', 'centre_sante'],
      required: true,
    },
    adresse: { type: String, required: true },
    ville: { type: String, required: true },
    telephone: { type: String, required: true },
    email: { type: String, required: true, unique: true, lowercase: true },
    numeroAutorisation: { type: String, required: true, unique: true },
    dateAutorisation: { type: Date },
    responsable: { type: String, required: true },
    status: {
      type: String,
      enum: ['pending', 'approved', 'suspended'],
      default: 'pending',
    },
    approvedAt: { type: Date },
    approvedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    createdAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

const Clinique = mongoose.model('Clinique', cliniqueSchema);

module.exports = Clinique;
