const express = require('express');
const Analyse = require('../models/Analyse');
const Patient = require('../models/Patient');
const User = require('../models/User');
const { authorize } = require('../middleware/auth');
const { fail } = require('../utils/apiResponse');
const { logAction } = require('../utils/logger');

const router = express.Router();

async function patientBelongsToClinic(patientId, clinicId) {
  const clinicUsers = await User.find({ entite: clinicId, entiteType: 'clinique', actif: true }).select('_id');
  return Boolean(await Patient.exists({
    _id: patientId,
    $or: [
      { clinique: clinicId },
      { createdBy: { $in: clinicUsers.map((user) => user._id) } },
    ],
  }));
}

router.get('/', authorize('medecin', 'secretaire'), async (req, res) => {
  try {
    const analyses = await Analyse.find({})
      .populate('patient', 'nom prenom dossierNumber')
      .populate('medecin', 'nom prenom role')
      .sort({ date: -1 })
      .limit(200);
    res.json(analyses);
  } catch (error) {
    res.status(500).json({ message: 'Erreur récupération analyses', error: error.message });
  }
});

router.post('/', authorize('medecin'), async (req, res) => {
  try {
    const { patientId, type, resultats, date } = req.body || {};
    if (!patientId || !type || !Array.isArray(resultats) || resultats.length === 0) {
      return fail(res, 'Patient, type et résultats requis', 400);
    }
    for (const result of resultats) {
      if (!result.parametre || result.valeur === undefined) {
        return fail(res, 'Chaque résultat doit avoir un paramètre et une valeur', 400);
      }
      if (result.statut && !['normal', 'bas', 'eleve', 'critique'].includes(result.statut)) {
        return fail(res, 'Statut de résultat invalide', 400);
      }
    }

    const analyse = await Analyse.create({
      patient: patientId,
      clinique: req.user.entite,
      medecin: req.user._id,
      type: type.trim(),
      resultats,
      date: date ? new Date(date) : new Date(),
    });
    await logAction({
      user: req.user._id,
      action: 'CREATE_ANALYSE',
      patientConcerne: patientId,
      details: `Analyse ${analyse.type} créée`,
      ipAddress: req.ip,
    });
    res.status(201).json({ message: 'Analyse créée', analyse });
  } catch (error) {
    res.status(500).json({ message: 'Erreur création analyse', error: error.message });
  }
});

module.exports = router;
