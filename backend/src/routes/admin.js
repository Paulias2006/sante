const express = require('express');
const bcrypt = require('bcryptjs');
const Clinique = require('../models/Clinique');
const Pharmacie = require('../models/Pharmacie');
const User = require('../models/User');
const Patient = require('../models/Patient');
const Ordonnance = require('../models/Ordonnance');
const CommandeCarte = require('../models/CommandeCarte');
const Log = require('../models/Log');
const { fail } = require('../utils/apiResponse');
const { authorize } = require('../middleware/auth');

const router = express.Router();

router.use(authorize('admin'));

router.get('/stats', async (req, res) => {
  try {
    const [totalPatients, totalClinics, totalOrdonnances, totalCartes, pendingClinics, pendingPharmacies] = await Promise.all([
      Patient.countDocuments(),
      Clinique.countDocuments({ status: 'approved' }),
      Ordonnance.countDocuments(),
      CommandeCarte.countDocuments({ status: 'delivered' }),
      Clinique.countDocuments({ status: 'pending' }),
      Pharmacie.countDocuments({ status: 'pending' }),
    ]);

    res.json({
      totalPatients,
      totalClinics,
      totalOrdonnances,
      totalCartes,
      pendingClinics,
      pendingPharmacies,
    });
  } catch (error) {
    res.status(500).json({ message: 'Erreur stats admin', error: error.message });
  }
});

router.get('/cliniques', async (req, res) => {
  try {
    const { status, ville } = req.query;
    const filters = {};
    if (status) filters.status = status;
    if (ville) filters.ville = ville;

    const cliniques = await Clinique.find(filters).sort({ createdAt: -1 });
    res.json(cliniques);
  } catch (error) {
    res.status(500).json({ message: 'Erreur récupération cliniques', error: error.message });
  }
});

router.get('/patients', async (req, res) => {
  try {
    const patients = await Patient.find().sort({ createdAt: -1 }).limit(200);
    res.json(patients);
  } catch (error) {
    res.status(500).json({ message: 'Erreur récupération patients admin', error: error.message });
  }
});

router.patch('/cliniques/:id/approve', async (req, res) => {
  try {
    const clinique = await Clinique.findByIdAndUpdate(
      req.params.id,
      { status: 'approved', approvedAt: new Date(), approvedBy: req.user._id },
      { new: true }
    );

    if (!clinique) return fail(res, 'Clinique introuvable', 404);
    res.json({ message: 'Clinique approuvée', clinique });
  } catch (error) {
    res.status(500).json({ message: 'Erreur approbation clinique', error: error.message });
  }
});

router.patch('/cliniques/:id/reject', async (req, res) => {
  try {
    const clinique = await Clinique.findByIdAndUpdate(req.params.id, { status: 'pending' }, { new: true });
    if (!clinique) return fail(res, 'Clinique introuvable', 404);
    res.json({ message: 'Clinique rejetée', clinique });
  } catch (error) {
    res.status(500).json({ message: 'Erreur rejet clinique', error: error.message });
  }
});

router.patch('/cliniques/:id/suspend', async (req, res) => {
  try {
    const clinique = await Clinique.findByIdAndUpdate(req.params.id, { status: 'suspended' }, { new: true });
    if (!clinique) return fail(res, 'Clinique introuvable', 404);
    res.json({ message: 'Clinique suspendue', clinique });
  } catch (error) {
    res.status(500).json({ message: 'Erreur suspension clinique', error: error.message });
  }
});

router.get('/pharmacies', async (req, res) => {
  try {
    const { status, ville } = req.query;
    const filters = {};
    if (status) filters.status = status;
    if (ville) filters.ville = ville;

    const pharmacies = await Pharmacie.find(filters).sort({ createdAt: -1 });
    res.json(pharmacies);
  } catch (error) {
    res.status(500).json({ message: 'Erreur récupération pharmacies', error: error.message });
  }
});

router.patch('/pharmacies/:id/approve', async (req, res) => {
  try {
    const pharmacie = await Pharmacie.findByIdAndUpdate(req.params.id, { status: 'approved' }, { new: true });
    if (!pharmacie) return fail(res, 'Pharmacie introuvable', 404);
    res.json({ message: 'Pharmacie approuvée', pharmacie });
  } catch (error) {
    res.status(500).json({ message: 'Erreur approbation pharmacie', error: error.message });
  }
});

router.patch('/pharmacies/:id/reject', async (req, res) => {
  try {
    const pharmacie = await Pharmacie.findByIdAndUpdate(req.params.id, { status: 'pending' }, { new: true });
    if (!pharmacie) return fail(res, 'Pharmacie introuvable', 404);
    res.json({ message: 'Pharmacie rejetée', pharmacie });
  } catch (error) {
    res.status(500).json({ message: 'Erreur rejet pharmacie', error: error.message });
  }
});

router.patch('/pharmacies/:id/suspend', async (req, res) => {
  try {
    const pharmacie = await Pharmacie.findByIdAndUpdate(req.params.id, { status: 'suspended' }, { new: true });
    if (!pharmacie) return fail(res, 'Pharmacie introuvable', 404);
    res.json({ message: 'Pharmacie suspendue', pharmacie });
  } catch (error) {
    res.status(500).json({ message: 'Erreur suspension pharmacie', error: error.message });
  }
});

router.get('/cartes', async (req, res) => {
  try {
    const commandes = await CommandeCarte.find()
      .populate('clinique')
      .populate('patients')
      .sort({ createdAt: -1 });
    res.json(commandes);
  } catch (error) {
    res.status(500).json({ message: 'Erreur récupération commandes cartes', error: error.message });
  }
});

router.get('/cartes/:id/pdf', async (req, res) => {
  try {
    const commande = await CommandeCarte.findById(req.params.id).populate('patients');
    if (!commande) return fail(res, 'Commande introuvable', 404);
    res.json({ message: 'PDF de commande généré', commandeId: commande._id, patientCount: commande.patients.length });
  } catch (error) {
    res.status(500).json({ message: 'Erreur génération PDF', error: error.message });
  }
});

router.patch('/cartes/:id/status', async (req, res) => {
  try {
    const { status } = req.body;
    const commande = await CommandeCarte.findByIdAndUpdate(req.params.id, { status, deliveredAt: status === 'delivered' ? new Date() : null }, { new: true });
    if (!commande) return fail(res, 'Commande introuvable', 404);
    res.json({ message: 'Statut mis à jour', commande });
  } catch (error) {
    res.status(500).json({ message: 'Erreur mise à jour statut commande', error: error.message });
  }
});

router.get('/logs', async (req, res) => {
  try {
    const logs = await Log.find().populate('user', 'nom prenom email role').sort({ timestamp: -1 }).limit(100);
    res.json(logs);
  } catch (error) {
    res.status(500).json({ message: 'Erreur récupération logs', error: error.message });
  }
});

module.exports = router;
