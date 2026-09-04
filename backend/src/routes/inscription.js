const express = require('express');
const bcrypt = require('bcryptjs');
const Clinique = require('../models/Clinique');
const Pharmacie = require('../models/Pharmacie');
const User = require('../models/User');
const { fail } = require('../utils/apiResponse');

const router = express.Router();

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
