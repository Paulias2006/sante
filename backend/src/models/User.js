const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    passwordHash: {
      type: String,
      required: true,
    },
    role: {
      type: String,
      enum: ['admin', 'secretaire', 'medecin', 'pharmacien', 'patient'],
      required: true,
    },
    entite: {
      type: mongoose.Schema.Types.ObjectId,
      refPath: 'entiteType',
      required: true,
    },
    entiteType: {
      type: String,
      enum: ['clinique', 'pharmacie'],
      required: true,
    },
    patientId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Patient',
      default: null,
    },
    nom: { type: String, required: true },
    prenom: { type: String, required: true },
    actif: {
      type: Boolean,
      default: true,
    },
  },
  { timestamps: true }
);

const User = mongoose.model('User', userSchema);

module.exports = User;
