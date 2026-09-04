const mongoose = require('mongoose');

const medicamentDelivreSchema = new mongoose.Schema(
  {
    nom: { type: String, required: true },
    delivre: { type: Boolean, required: true },
    raisonNonDelivrance: { type: String, default: '' },
  },
  { _id: false }
);

const delivranceSchema = new mongoose.Schema(
  {
    ordonnance: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Ordonnance',
      required: true,
    },
    patient: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Patient',
      required: true,
    },
    pharmacie: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Pharmacie',
      required: true,
    },
    pharmacien: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    medicamentsDelivres: [medicamentDelivreSchema],
    status: {
      type: String,
      enum: ['delivered', 'partial'],
      default: 'delivered',
    },
    date: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

const Delivrance = mongoose.model('Delivrance', delivranceSchema);

module.exports = Delivrance;
