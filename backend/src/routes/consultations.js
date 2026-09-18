const express = require('express');
const Consultation = require('../models/Consultation');
const Ordonnance = require('../models/Ordonnance');
const Patient = require('../models/Patient');
const User = require('../models/User');
const { authorize } = require('../middleware/auth');
const { fail } = require('../utils/apiResponse');
const { logAction } = require('../utils/logger');

const router = express.Router();

router.get('/', authorize('medecin', 'secretaire'), async (req, res) => {
  try {
    const filters = {};

    const consultations = await Consultation.find(filters)
      .populate('patient', 'nom prenom dossierNumber groupeSanguin allergies telephone')
      .populate('medecin', 'nom prenom role')
      .sort({ date: -1 })
      .limit(200);

    res.json(consultations);
  } catch (error) {
    res.status(500).json({ message: 'Erreur récupération consultations', error: error.message });
  }
});

router.post('/', authorize('medecin'), async (req, res) => {
  try {
    const { patientId, motif, diagnostic, notes, constantes } = req.body;

    if (!patientId || !motif || !diagnostic) {
      return fail(res, 'patientId, motif et diagnostic requis', 400);
    }

    const patient = await Patient.findById(patientId);
    if (!patient) return fail(res, 'Patient introuvable', 404);

    const consultation = await Consultation.create({
      patient: patientId,
      clinique: req.user.entite,
      medecin: req.user._id,
      motif,
      diagnostic,
      notes: notes || '',
      constantes: constantes || {},
    });

    await logAction({
      user: req.user._id,
      action: 'CREATE_CONSULTATION',
      patientConcerne: patientId,
      details: `Consultation créée pour ${patient.dossierNumber}`,
      ipAddress: req.ip,
    });

    res.status(201).json({ message: 'Consultation créée', consultation });
  } catch (error) {
    res.status(500).json({ message: 'Erreur création consultation', error: error.message });
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

    const consultations = await Consultation.find({ patient: req.params.patientId }).sort({ date: -1 });
    res.json(consultations);
  } catch (error) {
    res.status(500).json({ message: 'Erreur récupération consultations', error: error.message });
  }
});

router.get('/:id', authorize('medecin', 'secretaire'), async (req, res) => {
  try {
    const consultation = await Consultation.findOne({
      _id: req.params.id,
      clinique: req.user.entite,
    });
    if (!consultation) return fail(res, 'Consultation introuvable', 404);
    res.json(consultation);
  } catch (error) {
    res.status(500).json({ message: 'Erreur détail consultation', error: error.message });
  }
});

module.exports = router;
