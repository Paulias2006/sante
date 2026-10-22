const express = require('express');
const Clinique = require('../models/Clinique');
const Pharmacie = require('../models/Pharmacie');
const User = require('../models/User');

const router = express.Router();

function searchFilter(search, fields) {
  const value = String(search || '').trim();
  if (!value) return {};
  const escaped = value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return { $or: fields.map((field) => ({ [field]: { $regex: escaped, $options: 'i' } })) };
}

router.get('/cliniques', async (req, res) => {
  try {
    const cliniques = await Clinique.find({
      status: 'approved',
      ...searchFilter(req.query.search, ['nom', 'ville', 'adresse', 'type']),
    })
      .select('_id nom type ville adresse telephone email')
      .sort({ nom: 1 })
      .limit(100);
    res.json(cliniques);
  } catch (error) {
    res.status(500).json({ message: 'Erreur récupération cliniques', error: error.message });
  }
});

router.get('/pharmacies', async (req, res) => {
  try {
    const pharmacies = await Pharmacie.find({
      status: 'approved',
      ...searchFilter(req.query.search, ['nom', 'ville', 'adresse']),
    })
      .select('_id nom ville adresse telephone email')
      .sort({ nom: 1 })
      .limit(100);
    res.json(pharmacies);
  } catch (error) {
    res.status(500).json({ message: 'Erreur récupération pharmacies', error: error.message });
  }
});

router.get('/medecins', async (req, res) => {
  try {
    const doctors = await User.find({ role: 'medecin', actif: true })
      .select('_id nom prenom telephone adresse entite entiteType')
      .populate('entite', 'nom ville adresse status')
      .sort({ nom: 1, prenom: 1 })
      .limit(200);
    const search = String(req.query.search || '').trim().toLowerCase();
    const result = doctors
      .filter((doctor) => doctor.entite?.status === 'approved')
      .filter((doctor) => {
        if (!search) return true;
        const name = `${doctor.prenom} ${doctor.nom}`.toLowerCase();
        const entity = `${doctor.entite?.nom || ''} ${doctor.entite?.ville || ''}`.toLowerCase();
        return name.includes(search) || entity.includes(search);
      })
      .map((doctor) => ({
        _id: doctor._id,
        nom: doctor.nom,
        prenom: doctor.prenom,
        telephone: doctor.telephone,
        adresse: doctor.adresse,
        clinique: doctor.entite,
      }));
    res.json(result);
  } catch (error) {
    res.status(500).json({ message: 'Erreur récupération médecins', error: error.message });
  }
});

module.exports = router;
