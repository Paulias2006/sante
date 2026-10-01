const express = require('express');
const bcrypt = require('bcryptjs');
const PDFDocument = require('pdfkit');
const QRCode = require('qrcode');
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

    const patient = commande.patients[0];
    const qrData = patient?.qrToken
      ? await QRCode.toDataURL(patient.qrToken, { margin: 1, width: 220 })
      : null;
    const document = new PDFDocument({ size: 'A4', margin: 36 });
    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `inline; filename="carte-${commande._id}.pdf"`);
    document.pipe(res);
    document.fontSize(18).fillColor('#0A6B55').text('SantéTogo - Carte patient');
    document.moveDown(1);
    document.roundedRect(150, 180, 295, 188, 12).fill('#0A6B55');
    document.fillColor('#FFFFFF').fontSize(19).text('SantéTogo', 170, 202);
    document.fontSize(8).text('DOSSIER MEDICAL NUMERIQUE', 170, 228);
    document.fontSize(17).text(`${patient?.prenom || ''} ${patient?.nom || ''}`.trim(), 170, 275);
    document.fontSize(10).text(`Dossier ${patient?.dossierNumber || '—'}  ·  Groupe ${patient?.groupeSanguin || '—'}`, 170, 305);
    if (qrData) document.image(Buffer.from(qrData.split(',')[1], 'base64'), 350, 276, { width: 72, height: 72 });
    document.fillColor('#1A1A1A').fontSize(9).text(`Commande ${commande._id}`, 36, 420);
    document.text(`Statut : ${commande.status}`);
    document.text(`Nombre de cartes : ${commande.nombreCartes}`);
    document.end();
  } catch (error) {
    res.status(500).json({ message: 'Erreur génération PDF', error: error.message });
  }
});

router.patch('/cartes/:id/status', async (req, res) => {
  try {
    const { status } = req.body;
    if (!['pending', 'printing', 'shipped', 'delivered'].includes(status)) {
      return fail(res, 'Statut de carte invalide', 400);
    }
    const commande = await CommandeCarte.findByIdAndUpdate(req.params.id, { status, deliveredAt: status === 'delivered' ? new Date() : null }, { new: true });
    if (!commande) return fail(res, 'Commande introuvable', 404);
    res.json({ message: 'Statut mis à jour', commande });
  } catch (error) {
    res.status(500).json({ message: 'Erreur mise à jour statut commande', error: error.message });
  }
});

router.get('/logs', async (req, res) => {
  try {
    const limit = Math.min(Number(req.query.limit) || 100, 500);
    const page = Math.max(Number(req.query.page) || 1, 1);
    const logs = await Log.find()
      .populate('user', 'nom prenom email role')
      .sort({ timestamp: -1 })
      .skip((page - 1) * limit)
      .limit(limit);
    res.json(logs);
  } catch (error) {
    res.status(500).json({ message: 'Erreur récupération logs', error: error.message });
  }
});

module.exports = router;
