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
    if (ordonnance.expireAt && ordonnance.expireAt <= new Date()) {
      return fail(res, 'ORDONNANCE EXPIRÉE', 409);
    }
    if (
      ordonnance.patient.qrRevokedAt &&
      payload.iat &&
      payload.iat * 1000 <= ordonnance.patient.qrRevokedAt.getTime()
    ) {
      return fail(res, 'QR patient révoqué', 401);
    }

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
    const from = req.query.from ? new Date(req.query.from) : null;
    const to = req.query.to ? new Date(req.query.to) : null;
    const date = {};
    if (from && !Number.isNaN(from.getTime())) date.$gte = from;
    if (to && !Number.isNaN(to.getTime())) date.$lte = to;
    if (!from && !to) {
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);
      date.$gte = todayStart;
    }
    const livraisons = await Delivrance.find({ pharmacie: req.user.entite, date })
      .populate('patient')
      .sort({ date: -1 });
    res.json(livraisons);
  } catch (error) {
    res.status(500).json({ message: 'Erreur récupération délivrances', error: error.message });
  }
});

router.patch('/delivrances/:id/return', async (req, res) => {
  try {
    const delivery = await Delivrance.findOne({
      _id: req.params.id,
      pharmacie: req.user.entite,
      status: { $in: ['delivered', 'partial'] },
    });
    if (!delivery) return fail(res, 'Délivrance introuvable ou déjà retournée', 404);
    delivery.status = 'returned';
    delivery.returnedAt = new Date();
    delivery.returnReason = (req.body?.reason || 'Retour enregistré').toString().trim();
    await delivery.save();
    await Ordonnance.findByIdAndUpdate(delivery.ordonnance, { status: 'active' });
    res.json({ message: 'Retour enregistré', delivrance: delivery });
  } catch (error) {
    res.status(500).json({ message: 'Erreur retour délivrance', error: error.message });
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
