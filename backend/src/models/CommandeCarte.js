const mongoose = require('mongoose');

const commandeCarteSchema = new mongoose.Schema(
  {
    clinique: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Clinique',
      required: true,
    },
    patients: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Patient' }],
    nombreCartes: { type: Number, required: true },
    status: {
      type: String,
      enum: ['pending', 'printing', 'shipped', 'delivered'],
      default: 'pending',
    },
    createdAt: { type: Date, default: Date.now },
    deliveredAt: { type: Date },
  },
  { timestamps: true }
);

const CommandeCarte = mongoose.model('CommandeCarte', commandeCarteSchema);

module.exports = CommandeCarte;
