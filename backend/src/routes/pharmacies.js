const express = require('express');
const { authorize } = require('../middleware/auth');
const Ordonnance = require('../models/Ordonnance');
const Patient = require('../models/Patient');
const Delivrance = require('../models/Delivrance');
const { fail } = require('../utils/apiResponse');

const router = express.Router();

router.use(authorize('pharmacien'));

router.get('/scan/:qrToken', async (req, res) => {
  try {
    const { verifyQrToken } = require('../config/jwt');
    const payload = verifyQrToken(req.params.qrToken);
    const ordonnance = await Ordonnance.findById(payload.ordonnanceId).populate('patient');

    if (!ordonnance) return fail(res, 'ORDONNANCE INVALIDE', 400);
    if (ordonnance.status === 'delivered') return fail(res, 'DÉJÀ UTILISÉE', 409);

    const patient = ordonnance.patient;
    res.json({
      patient: {
        nom: patient.nom,
        prenom: patient.prenom,
        age: patient.dateNaissance ? new Date().getFullYear() - new Date(patient.dateNaissance).getFullYear() : null,
        groupeSanguin: patient.groupeSanguin,
        allergies: patient.allergies || [],
      },
      ordonnance: {
        _id: ordonnance._id,
        medicaments: ordonnance.medicaments,
        instructionsGenerales: ordonnance.instructionsGenerales,
      },
    });
  } catch (error) {
    return fail(res, 'ORDONNANCE INVALIDE', 401);
  }
});

router.get('/delivrances', async (req, res) => {
  try {
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const livraisons = await Delivrance.find({ pharmacie: req.user.entite, date: { $gte: todayStart } }).populate('patient').sort({ date: -1 });
    res.json(livraisons);
  } catch (error) {
    res.status(500).json({ message: 'Erreur récupération délivrances', error: error.message });
  }
});

router.get('/stats', async (req, res) => {
  try {
    const stats = await Delivrance.aggregate([
      { $match: { pharmacie: req.user.entite } },
      {
        $group: {
          _id: { $dateToString: { format: '%Y-%m-%d', date: '$date' } },
          count: { $sum: 1 },
        },
      },
      { $sort: { _id: 1 } },
    ]);

    const total = stats.reduce((sum, item) => sum + (item.count || 0), 0);
    res.json({
      count: total,
      dailyStats: stats,
    });
  } catch (error) {
    res.status(500).json({ message: 'Erreur statistiques pharmacie', error: error.message });
  }
});

module.exports = router;
