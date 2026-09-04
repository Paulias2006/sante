const express = require('express');
const bcrypt = require('bcryptjs');
const { signQrToken } = require('../config/jwt');
const { authorize } = require('../middleware/auth');
const Patient = require('../models/Patient');
const Consultation = require('../models/Consultation');
const Clinique = require('../models/Clinique');
const User = require('../models/User');
const Ordonnance = require('../models/Ordonnance');
const CommandeCarte = require('../models/CommandeCarte');
const Analyse = require('../models/Analyse');
const Delivrance = require('../models/Delivrance');
const { logAction } = require('../utils/logger');
const { fail } = require('../utils/apiResponse');
const { generateDossierNumber } = require('../utils/generateNumber');

const router = express.Router();

router.use(authorize('secretaire', 'medecin', 'patient'));

router.post('/', async (req, res) => {
  try {
    const user = req.user;
    const clinique = await Clinique.findById(user.entite);

    if (!clinique || clinique.status !== 'approved') {
      return fail(res, 'La clinique n\'est pas approuvée pour créer des patients', 403);
    }

    const {
      nom,
      prenom,
      dateNaissance,
      sexe,
      telephone,
      adresse,
      groupeSanguin,
      allergies,
    } = req.body;

    if (!nom || !prenom || !dateNaissance || !sexe || !telephone || !adresse || !groupeSanguin) {
      return fail(res, 'Tous les champs du patient sont requis', 400);
    }

    let dossierNumber;
    let unique = false;
    while (!unique) {
      dossierNumber = generateDossierNumber();
      const existing = await Patient.findOne({ dossierNumber });
      if (!existing) unique = true;
    }

    const temporaryQrToken = `patient-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
    const patient = await Patient.create({
      dossierNumber,
      qrToken: temporaryQrToken,
      nom,
      prenom,
      dateNaissance: new Date(dateNaissance),
      sexe,
      telephone,
      adresse,
      groupeSanguin,
      allergies: allergies || [],
      createdBy: user._id,
    });

    const qrToken = signQrToken({ patientId: patient._id.toString(), type: 'permanent' }, '100y');
    patient.qrToken = qrToken;
    await patient.save();

    await logAction({
      user: user._id,
      action: 'CREATE_PATIENT',
      patientConcerne: patient._id,
      details: `Création du dossier ${patient.dossierNumber}`,
      ipAddress: req.ip,
    });

    res.status(201).json({ message: 'Patient créé avec succès', patient });
  } catch (error) {
    res.status(500).json({ message: 'Erreur création patient', error: error.message });
  }
});

router.get('/', async (req, res) => {
  try {
    const { search } = req.query;
    let filters = {};

    if (req.user.role === 'patient') {
      filters = { _id: req.user.patientId };
    } else if (req.user.role === 'medecin' || req.user.role === 'secretaire') {
      const activeClinicUsers = await User.find({ entite: req.user.entite, actif: true }).select('_id');
      const clinicUserIds = activeClinicUsers.map((user) => user._id);
      filters = clinicUserIds.length > 0 ? { createdBy: { $in: clinicUserIds } } : { _id: null };
    } else {
      filters = { createdBy: req.user._id };
    }

    if (search) {
      filters.$or = [
        { nom: { $regex: search, $options: 'i' } },
        { prenom: { $regex: search, $options: 'i' } },
        { dossierNumber: { $regex: search, $options: 'i' } },
      ];
    }

    const patients = await Patient.find(filters).sort({ createdAt: -1 });
    res.json(patients);
  } catch (error) {
    res.status(500).json({ message: 'Erreur récupération patients', error: error.message });
  }
});

router.get('/qr/:qrToken', async (req, res) => {
  try {
    const { verifyQrToken } = require('../config/jwt');
    const payload = verifyQrToken(req.params.qrToken);

    const patient = await Patient.findById(payload.patientId);
    if (!patient) return fail(res, 'Patient introuvable', 404);

    res.json({ patient });
  } catch (error) {
    return fail(res, 'QR invalide ou expiré', 401);
  }
});

router.get('/numero/:dossierNumber', async (req, res) => {
  try {
    const patient = await Patient.findOne({ dossierNumber: req.params.dossierNumber.toUpperCase() });
    if (!patient) return fail(res, 'Patient introuvable', 404);
    res.json(patient);
  } catch (error) {
    res.status(500).json({ message: 'Erreur recherche patient', error: error.message });
  }
});

router.get('/:id', async (req, res) => {
  try {
    const isSelfAccess = req.user.role === 'patient' && req.user.patientId && req.user.patientId.toString() === req.params.id;
    if (req.user.role !== 'patient' && req.user.role !== 'medecin' && req.user.role !== 'secretaire') {
      return fail(res, 'Accès non autorisé', 403);
    }

    if (req.user.role === 'patient' && !isSelfAccess) {
      return fail(res, 'Accès non autorisé', 403);
    }

    const patient = await Patient.findById(req.params.id);
    if (!patient) return fail(res, 'Patient introuvable', 404);

    const consultations = await Consultation.find({ patient: patient._id }).populate('medecin', 'nom prenom role').sort({ date: -1 });
    const ordonnances = await Ordonnance.find({ patient: patient._id })
      .populate('medecin', 'nom prenom role')
      .populate('clinique', 'nom ville')
      .sort({ emiseAt: -1 });
    const analyses = await Analyse.find({ patient: patient._id })
      .populate('medecin', 'nom prenom role')
      .populate('clinique', 'nom ville')
      .sort({ date: -1 });
    const delivrances = await Delivrance.find({ patient: patient._id })
      .populate('pharmacie', 'nom ville')
      .populate('pharmacien', 'nom prenom role')
      .sort({ date: -1 });

    await logAction({
      user: req.user._id,
      action: 'VIEW_PATIENT',
      patientConcerne: patient._id,
      details: `Consultation du dossier ${patient.dossierNumber}`,
      ipAddress: req.ip,
    });

    res.json({ patient, consultations, ordonnances, analyses, delivrances });
  } catch (error) {
    res.status(500).json({ message: 'Erreur lecture patient', error: error.message });
  }
});

router.post('/:id/commande-carte', async (req, res) => {
  try {
    const patient = await Patient.findById(req.params.id);
    if (!patient) return fail(res, 'Patient introuvable', 404);

    const commande = await CommandeCarte.create({
      clinique: req.user.entite,
      patients: [patient._id],
      nombreCartes: 1,
      status: 'pending',
    });

    res.status(201).json({ message: 'Commande de carte créée', commande });
  } catch (error) {
    res.status(500).json({ message: 'Erreur création commande carte', error: error.message });
  }
});

module.exports = router;
