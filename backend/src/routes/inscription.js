const express = require('express');
const bcrypt = require('bcryptjs');
const Clinique = require('../models/Clinique');
const Pharmacie = require('../models/Pharmacie');
const User = require('../models/User');
const Patient = require('../models/Patient');
const { signQrToken, signAccessToken, signRefreshToken } = require('../config/jwt');
const { generateDossierNumber } = require('../utils/generateNumber');
const { fail } = require('../utils/apiResponse');

const router = express.Router();

router.get('/cliniques', async (req, res) => {
  try {
    const cliniques = await Clinique.find({ status: 'approved' })
      .select('_id nom type ville adresse')
      .sort({ nom: 1 });
    res.json(cliniques);
  } catch (error) {
    res.status(500).json({ message: 'Erreur récupération établissements', error: error.message });
  }
});

router.post('/patient', async (req, res) => {
  const session = await User.startSession();
  try {
    const {
      email,
      password,
      nom,
      prenom,
      dateNaissance,
      sexe,
      telephone,
      adresse,
      groupeSanguin,
      allergies = [],
      cliniqueId,
    } = req.body || {};
    const normalizedEmail = email?.trim().toLowerCase();
    const validGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    if (!normalizedEmail || !password || !nom || !prenom || !dateNaissance || !sexe ||
        !telephone || !adresse || !validGroups.includes(groupeSanguin) || !cliniqueId) {
      return fail(res, 'Tous les champs patient et l’établissement sont requis', 400);
    }
    if (password.length < 8) return fail(res, 'Le mot de passe doit contenir au moins 8 caractères', 400);
    if (!['M', 'F'].includes(sexe)) return fail(res, 'Sexe invalide', 400);
    const birthDate = new Date(dateNaissance);
    if (Number.isNaN(birthDate.getTime()) || birthDate > new Date()) {
      return fail(res, 'Date de naissance invalide', 400);
    }
    const clinique = await Clinique.findOne({ _id: cliniqueId, status: 'approved' });
    if (!clinique) return fail(res, 'Établissement indisponible ou non approuvé', 400);
    if (await User.exists({ email: normalizedEmail })) return fail(res, 'Cet email est déjà utilisé', 409);

    const passwordHash = await bcrypt.hash(password, 12);
    let dossierNumber;
    do {
      dossierNumber = generateDossierNumber();
    } while (await Patient.exists({ dossierNumber }));

    let createdUser;
    let patient;
    await session.withTransaction(async () => {
      [createdUser] = await User.create([{
        email: normalizedEmail,
        passwordHash,
        role: 'patient',
        entite: clinique._id,
        entiteType: 'clinique',
        patientId: null,
        nom: nom.trim(),
        prenom: prenom.trim(),
        actif: true,
      }], { session });

      const temporaryToken = `patient-${Date.now()}-${Math.random().toString(36).slice(2, 10)}`;
      [patient] = await Patient.create([{
        dossierNumber,
        qrToken: temporaryToken,
        nom: nom.trim(),
        prenom: prenom.trim(),
        dateNaissance: birthDate,
        sexe,
        telephone: telephone.trim(),
        adresse: adresse.trim(),
        groupeSanguin,
        allergies: Array.isArray(allergies) ? allergies : [],
        createdBy: createdUser._id,
        clinique: clinique._id,
      }], { session });

      patient.qrToken = signQrToken({ patientId: patient._id.toString(), type: 'permanent' }, '100y');
      await patient.save({ session });
      createdUser.patientId = patient._id;
      await createdUser.save({ session });
    });

    const accessToken = signAccessToken({ userId: createdUser._id, role: createdUser.role });
    const refreshToken = signRefreshToken({ userId: createdUser._id, role: createdUser.role });
    res.status(201).json({
      message: 'Compte patient créé avec succès',
      accessToken,
      refreshToken,
      user: {
        id: createdUser._id,
        email: createdUser.email,
        role: createdUser.role,
        nom: createdUser.nom,
        prenom: createdUser.prenom,
        entite: createdUser.entite,
        entiteType: createdUser.entiteType,
        patientId: createdUser.patientId,
      },
      patient,
    });
  } catch (error) {
    res.status(500).json({ message: 'Erreur inscription patient', error: error.message });
  } finally {
    await session.endSession();
  }
});

router.post('/clinique', async (req, res) => {
  try {
    const { nom, type, adresse, ville, telephone, email, numeroAutorisation, dateAutorisation, responsable } = req.body;

    if (!nom || !type || !adresse || !ville || !telephone || !email || !numeroAutorisation || !responsable) {
      return fail(res, 'Tous les champs requis doivent être fournis', 400);
    }

    const existing = await Clinique.findOne({ numeroAutorisation });
    if (existing) {
      return fail(res, 'Cette autorisation existe déjà', 409);
    }

    const clinique = await Clinique.create({
      nom,
      type,
      adresse,
      ville,
      telephone,
      email,
      numeroAutorisation,
      dateAutorisation,
      responsable,
      status: 'pending',
    });

    res.status(201).json({ message: 'Demande de clinique soumise avec succès', clinique });
  } catch (error) {
    res.status(500).json({ message: 'Erreur inscription clinique', error: error.message });
  }
});

router.post('/pharmacie', async (req, res) => {
  try {
    const { nom, adresse, ville, telephone, email, numeroAutorisation, dateAutorisation, responsable } = req.body;

    if (!nom || !adresse || !ville || !telephone || !email || !numeroAutorisation || !responsable) {
      return fail(res, 'Tous les champs requis doivent être fournis', 400);
    }

    const existing = await Pharmacie.findOne({ numeroAutorisation });
    if (existing) {
      return fail(res, 'Cette autorisation existe déjà', 409);
    }

    const pharmacie = await Pharmacie.create({
      nom,
      adresse,
      ville,
      telephone,
      email,
      numeroAutorisation,
      dateAutorisation,
      responsable,
      status: 'pending',
    });

    res.status(201).json({ message: 'Demande de pharmacie soumise avec succès', pharmacie });
  } catch (error) {
    res.status(500).json({ message: 'Erreur inscription pharmacie', error: error.message });
  }
});

module.exports = router;
