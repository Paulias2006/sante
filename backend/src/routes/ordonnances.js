const express = require('express');
const { signQrToken, verifyQrToken } = require('../config/jwt');
const { authorize } = require('../middleware/auth');
const Ordonnance = require('../models/Ordonnance');
const Patient = require('../models/Patient');
const Consultation = require('../models/Consultation');
const Delivrance = require('../models/Delivrance');
const Pharmacie = require('../models/Pharmacie');
const User = require('../models/User');
const { logAction } = require('../utils/logger');
const { fail } = require('../utils/apiResponse');

const router = express.Router();

router.get('/', authorize('medecin', 'secretaire'), async (req, res) => {
  try {
    const filters = {};

    const ordonnances = await Ordonnance.find(filters)
      .populate('patient', 'nom prenom dossierNumber groupeSanguin allergies telephone')
      .populate('medecin', 'nom prenom role')
      .populate('clinique', 'nom ville')
      .sort({ emiseAt: -1 })
      .limit(200);

    res.json(ordonnances);
  } catch (error) {
    res.status(500).json({ message: 'Erreur récupération ordonnances', error: error.message });
  }
});

router.post('/', authorize('medecin'), async (req, res) => {
  try {
    const { patientId, consultationId, medicaments, instructionsGenerales, validiteJours, renouvelable } = req.body;

    if (!patientId || !consultationId || !medicaments || medicaments.length === 0) {
      return fail(res, 'patientId, consultationId et médicaments requis', 400);
    }

    const patient = await Patient.findById(patientId);
    if (!patient) return fail(res, 'Patient introuvable', 404);

    const consultation = await Consultation.findById(consultationId);
    if (!consultation) return fail(res, 'Consultation introuvable', 404);
    if (
      consultation.patient.toString() !== patientId.toString() ||
      consultation.clinique.toString() !== req.user.entite.toString()
    ) {
      return fail(res, 'Consultation non liée à ce patient ou à cette clinique', 403);
    }

    const validityDays = validiteJours || 7;
    const expireAt = new Date(Date.now() + validityDays * 24 * 60 * 60 * 1000);

    const ordonnance = new Ordonnance({
      patient: patientId,
      consultation: consultationId,
      medecin: req.user._id,
      clinique: req.user.entite,
      medicaments,
      instructionsGenerales: instructionsGenerales || '',
      status: 'active',
      validiteJours: validityDays,
      renouvelable: !!renouvelable,
      nombreRenouvellements: 0,
      emiseAt: new Date(),
      expireAt,
    });

    ordonnance.qrToken = signQrToken(
      { ordonnanceId: ordonnance._id.toString(), patientId, type: 'ordonnance' },
      `${validityDays}d`
    );
    await ordonnance.save();

    await logAction({
      user: req.user._id,
      action: 'EMIT_ORDONNANCE',
      patientConcerne: patientId,
      details: `Ordonnance ${ordonnance._id} émise`,
      ipAddress: req.ip,
    });

    res.status(201).json({ message: 'Ordonnance émise', ordonnance });
  } catch (error) {
    res.status(500).json({ message: 'Erreur émission ordonnance', error: error.message });
  }
});

router.get('/patient/:patientId', authorize('medecin', 'secretaire', 'patient'), async (req, res) => {
  try {
    if (
      req.user.role === 'patient' &&
      (!req.user.patientId || req.user.patientId.toString() !== req.params.patientId)
    ) {
      return fail(res, 'Accès non autorisé', 403);
    }

    const ordonnances = await Ordonnance.find({ patient: req.params.patientId })
      .populate('medecin', 'nom prenom role')
      .populate('clinique', 'nom ville')
      .sort({ emiseAt: -1 });
    res.json(ordonnances);
  } catch (error) {
    res.status(500).json({ message: 'Erreur récupération ordonnances', error: error.message });
  }
});

router.get('/qr/:qrToken', authorize('pharmacien'), async (req, res) => {
  try {
    let ordonnance;
    let qrPayload;

    try {
      qrPayload = verifyQrToken(req.params.qrToken);
      if (qrPayload.type === 'ordonnance') {
        ordonnance = await Ordonnance.findById(qrPayload.ordonnanceId);
      } else if (qrPayload.type === 'permanent') {
        ordonnance = await Ordonnance.findOne({ patient: qrPayload.patientId, status: 'active' }).sort({ emiseAt: -1 });
      }
    } catch (_) {
      const patient = await Patient.findOne({ dossierNumber: req.params.qrToken.toUpperCase() });
      if (patient) {
        ordonnance = await Ordonnance.findOne({ patient: patient._id, status: 'active' }).sort({ emiseAt: -1 });
      }
    }

    if (!ordonnance) return fail(res, 'ORDONNANCE INVALIDE', 400);

    if (ordonnance.status === 'delivered') {
      return fail(res, 'DÉJÀ UTILISÉE', 409);
    }
    if (ordonnance.expireAt && ordonnance.expireAt <= new Date()) {
      return fail(res, 'ORDONNANCE EXPIRÉE', 409);
    }

    const previousDeliveries = await Delivrance.find({
      ordonnance: ordonnance._id,
      status: { $in: ['delivered', 'partial'] },
    }).select('medicamentsDelivres');
    const deliveredNames = new Set(
      previousDeliveries
        .flatMap((delivery) => delivery.medicamentsDelivres)
        .filter((medicine) => medicine.delivre)
        .map((medicine) => medicine.nom)
    );

    await ordonnance.populate([
      { path: 'patient' },
      { path: 'medecin', select: 'nom prenom role' },
      { path: 'clinique', select: 'nom ville' },
    ]);

    const patient = ordonnance.patient;
    if (
      qrPayload?.type === 'permanent' &&
      patient.qrRevokedAt &&
      qrPayload.iat &&
      qrPayload.iat * 1000 <= patient.qrRevokedAt.getTime()
    ) {
      return fail(res, 'QR patient révoqué', 401);
    }
    const allergies = patient.allergies || [];

    res.json({
      patient: {
        _id: patient._id,
        dossierNumber: patient.dossierNumber,
        nom: patient.nom,
        prenom: patient.prenom,
        telephone: patient.telephone,
        age: patient.dateNaissance ? new Date().getFullYear() - new Date(patient.dateNaissance).getFullYear() : null,
        groupeSanguin: patient.groupeSanguin,
        allergies,
      },
      ordonnance: {
        _id: ordonnance._id,
        qrToken: ordonnance.qrToken,
        medicaments: ordonnance.medicaments.filter((medicine) => !deliveredNames.has(medicine.nom)),
        instructionsGenerales: ordonnance.instructionsGenerales,
        medecin: ordonnance.medecin,
        clinique: ordonnance.clinique,
        emiseAt: ordonnance.emiseAt,
        expireAt: ordonnance.expireAt,
      },
    });
  } catch (error) {
    return fail(res, 'ORDONNANCE INVALIDE', 401);
  }
});

router.get('/:id', authorize('medecin', 'secretaire', 'pharmacien'), async (req, res) => {
  try {
    const ordonnance = await Ordonnance.findById(req.params.id)
      .populate('medecin', 'nom prenom role')
      .populate('clinique', 'nom ville');
    if (!ordonnance) return fail(res, 'Ordonnance introuvable', 404);
    res.json(ordonnance);
  } catch (error) {
    res.status(500).json({ message: 'Erreur détail ordonnance', error: error.message });
  }
});

router.patch('/:id/deliver', authorize('pharmacien'), async (req, res) => {
  try {
    const pharmacie = await Pharmacie.findById(req.user.entite);
    if (!pharmacie || pharmacie.status !== 'approved') {
      return fail(res, 'Pharmacie non approuvée', 403);
    }
    const ordonnance = await Ordonnance.findById(req.params.id);
    if (!ordonnance) return fail(res, 'Ordonnance introuvable', 404);

    if (ordonnance.status === 'delivered') {
      return fail(res, 'DÉJÀ UTILISÉE', 409);
    }
    if (ordonnance.expireAt && ordonnance.expireAt <= new Date()) {
      return fail(res, 'ORDONNANCE EXPIRÉE', 409);
    }

    const { medicamentsDelivres } = req.body;
    const previousDeliveries = await Delivrance.find({
      ordonnance: ordonnance._id,
      status: { $in: ['delivered', 'partial'] },
    }).select('medicamentsDelivres');
    const deliveredNames = new Set(
      previousDeliveries
        .flatMap((delivery) => delivery.medicamentsDelivres)
        .filter((medicine) => medicine.delivre)
        .map((medicine) => medicine.nom)
    );
    const deliveredItems = (medicamentsDelivres || ordonnance.medicaments.map((m) => ({ nom: m.nom, delivre: true, raisonNonDelivrance: '' })))
      .filter((medicine) => !deliveredNames.has(medicine.nom));
    if (deliveredItems.length === 0) return fail(res, 'Aucun médicament restant à délivrer', 409);
    const isPartial = deliveredItems.some((m) => m.delivre === false);
    const updated = await Ordonnance.findByIdAndUpdate(
      req.params.id,
      { status: isPartial ? 'partial' : 'delivered' },
      { new: true }
    );

    await Delivrance.create({
      ordonnance: ordonnance._id,
      patient: ordonnance.patient,
      pharmacie: req.user.entite,
      pharmacien: req.user._id,
      medicamentsDelivres: deliveredItems,
      status: isPartial ? 'partial' : 'delivered',
      date: new Date(),
    });

    await logAction({
      user: req.user._id,
      action: 'DELIVER_ORDONNANCE',
      patientConcerne: ordonnance.patient,
      details: `Délivrance confirmation ordonnance ${ordonnance._id}`,
      ipAddress: req.ip,
    });

    res.json({ message: 'Délivrance confirmée', ordonnance: updated });
  } catch (error) {
    res.status(500).json({ message: 'Erreur délivrance ordonnance', error: error.message });
  }
});

module.exports = router;
