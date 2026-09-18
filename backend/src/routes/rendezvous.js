const express = require('express');
const RendezVous = require('../models/RendezVous');
const Patient = require('../models/Patient');
const User = require('../models/User');
const { authorize } = require('../middleware/auth');
const { fail } = require('../utils/apiResponse');

const router = express.Router();

async function clinicPatient(patientId, clinicId) {
  const users = await User.find({ entite: clinicId, entiteType: 'clinique', actif: true }).select('_id');
  return Patient.exists({
    _id: patientId,
    $or: [
      { clinique: clinicId },
      { createdBy: { $in: users.map((user) => user._id) } },
    ],
  });
}

router.get('/', authorize('medecin', 'secretaire'), async (req, res) => {
  try {
    const appointments = await RendezVous.find({ clinique: req.user.entite })
      .populate('patient', 'nom prenom dossierNumber')
      .sort({ date: 1 })
      .limit(200);
    res.json(appointments);
  } catch (error) {
    res.status(500).json({ message: 'Erreur récupération rendez-vous', error: error.message });
  }
});

router.post('/', authorize('medecin', 'secretaire'), async (req, res) => {
  try {
    const { patientId, date, motif, notes } = req.body || {};
    if (!patientId || !date || !motif) return fail(res, 'Patient, date et motif requis', 400);
    const appointmentDate = new Date(date);
    if (Number.isNaN(appointmentDate.getTime()) || appointmentDate < new Date()) {
      return fail(res, 'Date de rendez-vous invalide', 400);
    }
    const appointment = await RendezVous.create({
      patient: patientId,
      clinique: req.user.entite,
      createdBy: req.user._id,
      date: appointmentDate,
      motif: motif.trim(),
      notes: notes || '',
    });
    res.status(201).json({ message: 'Rendez-vous créé', rendezVous: appointment });
  } catch (error) {
    res.status(500).json({ message: 'Erreur création rendez-vous', error: error.message });
  }
});

router.patch('/:id/status', authorize('medecin', 'secretaire'), async (req, res) => {
  try {
    const allowed = ['planned', 'confirmed', 'completed', 'cancelled', 'no_show'];
    if (!allowed.includes(req.body?.status)) return fail(res, 'Statut invalide', 400);
    const appointment = await RendezVous.findOneAndUpdate(
      { _id: req.params.id, clinique: req.user.entite },
      { status: req.body.status },
      { new: true }
    );
    if (!appointment) return fail(res, 'Rendez-vous introuvable', 404);
    res.json({ message: 'Statut mis à jour', rendezVous: appointment });
  } catch (error) {
    res.status(500).json({ message: 'Erreur mise à jour rendez-vous', error: error.message });
  }
});

module.exports = router;
