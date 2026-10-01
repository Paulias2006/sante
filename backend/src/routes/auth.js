const express = require('express');
const bcrypt = require('bcryptjs');
const { signAccessToken, signRefreshToken, verifyRefreshToken, verifyAccessToken } = require('../config/jwt');
const User = require('../models/User');
const Clinique = require('../models/Clinique');
const Pharmacie = require('../models/Pharmacie');
const { logAction } = require('../utils/logger');
const { fail } = require('../utils/apiResponse');

const router = express.Router();

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return fail(res, 'Email et mot de passe requis', 400);
    }

    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user || !user.actif) {
      return fail(res, 'Identifiants invalides', 401);
    }

    const isValid = await bcrypt.compare(password, user.passwordHash);
    if (!isValid) {
      return fail(res, 'Identifiants invalides', 401);
    }

    const accessToken = signAccessToken({ userId: user._id, role: user.role });
    const refreshToken = signRefreshToken({ userId: user._id, role: user.role });

    await logAction({
      user: user._id,
      action: 'LOGIN',
      details: 'Connexion utilisateur',
      ipAddress: req.ip,
    });

    res.json({
      accessToken,
      refreshToken,
      user: {
        id: user._id,
        email: user.email,
        role: user.role,
        nom: user.nom,
        prenom: user.prenom,
        entite: user.entite,
        entiteType: user.entiteType,
        patientId: user.patientId || null,
      },
    });
  } catch (error) {
    res.status(500).json({ message: 'Erreur de connexion', error: error.message });
  }
});

router.post('/refresh', async (req, res) => {
  const { refreshToken } = req.body;

  if (!refreshToken) {
    return fail(res, 'Refresh token requis', 400);
  }

  try {
    const payload = verifyRefreshToken(refreshToken);
    const user = await User.findById(payload.userId);

    if (!user || !user.actif) {
      return fail(res, 'Session invalide', 401);
    }

    const accessToken = signAccessToken({ userId: user._id, role: user.role });
    return res.json({ accessToken });
  } catch (error) {
    return fail(res, 'Refresh token invalide', 401);
  }
});

router.post('/logout', async (req, res) => {
  const { userId } = req.body;

  if (userId) {
    await logAction({
      user: userId,
      action: 'LOGOUT',
      details: 'Déconnexion utilisateur',
      ipAddress: req.ip,
    });
  }

  res.json({ message: 'Déconnexion réussie' });
});

router.patch('/password', async (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return fail(res, 'Token requis', 401);
  }

  try {
    const { userId } = verifyAccessToken(authHeader.split(' ')[1]);
    const { currentPassword, newPassword } = req.body || {};
    if (!currentPassword || !newPassword || newPassword.length < 8) {
      return fail(res, 'Mot de passe actuel et nouveau mot de passe de 8 caractères requis', 400);
    }
    const user = await User.findById(userId);
    if (!user || !(await bcrypt.compare(currentPassword, user.passwordHash))) {
      return fail(res, 'Mot de passe actuel incorrect', 401);
    }
    user.passwordHash = await bcrypt.hash(newPassword, 12);
    await user.save();
    await logAction({
      user: user._id,
      action: 'UPDATE_PASSWORD',
      details: 'Mot de passe modifié depuis le profil',
      ipAddress: req.ip,
    });
    return res.json({ message: 'Mot de passe modifié avec succès' });
  } catch (error) {
    return fail(res, 'Erreur modification mot de passe', 500);
  }
});

router.get('/me', async (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return fail(res, 'Token requis', 401);
  }

  try {
    const token = authHeader.split(' ')[1];
    const { userId } = verifyAccessToken(token);
    const user = await User.findById(userId).select('-passwordHash');

    if (!user) {
      return fail(res, 'Utilisateur introuvable', 404);
    }

    const entite = user.entiteType === 'pharmacie'
      ? await Pharmacie.findById(user.entite)
      : await Clinique.findById(user.entite);

    res.json({ user, entite });
  } catch (error) {
    return fail(res, 'Token invalide', 401);
  }
});

router.patch('/me', async (req, res) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return fail(res, 'Token requis', 401);
  }

  try {
    const token = authHeader.split(' ')[1];
    const { userId } = verifyAccessToken(token);
    const user = await User.findById(userId);

    if (!user) {
      return fail(res, 'Utilisateur introuvable', 404);
    }

    const {
      nom,
      prenom,
      telephone,
      adresse,
      notificationsEnabled,
      photo,
      entite: entitePayload = {},
    } = req.body || {};
    if (typeof nom === 'string' && nom.trim()) user.nom = nom.trim();
    if (typeof prenom === 'string' && prenom.trim()) user.prenom = prenom.trim();
    if (typeof telephone === 'string') user.telephone = telephone.trim();
    if (typeof adresse === 'string') user.adresse = adresse.trim();
    if (typeof notificationsEnabled === 'boolean') {
      user.notificationsEnabled = notificationsEnabled;
    }
    if (user.role === 'patient' && user.patientId) {
      const Patient = require('../models/Patient');
      const patient = await Patient.findById(user.patientId);
      if (patient) {
        if (typeof nom === 'string' && nom.trim()) patient.nom = nom.trim();
        if (typeof prenom === 'string' && prenom.trim()) patient.prenom = prenom.trim();
        if (typeof telephone === 'string') patient.telephone = telephone.trim();
        if (typeof adresse === 'string') patient.adresse = adresse.trim();
        if (typeof photo === 'string') patient.photo = photo;
        await patient.save();
      }
    }
    await user.save();

    if (user.role === 'patient') {
      const refreshedPatientUser = await User.findById(user._id).select('-passwordHash');
      return res.json({
        message: 'Profil patient mis à jour',
        user: refreshedPatientUser,
        entite: await Clinique.findById(user.entite),
      });
    }

    const model = user.entiteType === 'pharmacie' ? Pharmacie : Clinique;
    const entite = await model.findById(user.entite);
    if (entite) {
      const allowed = [
        'nom',
        'adresse',
        'ville',
        'telephone',
        'email',
        'responsable',
        'dateAutorisation',
      ];
      if (user.entiteType === 'clinique') allowed.push('type');

      for (const field of allowed) {
        if (Object.prototype.hasOwnProperty.call(entitePayload, field)) {
          const value = entitePayload[field];
          if (typeof value === 'string') {
            entite[field] = field === 'email' ? value.trim().toLowerCase() : value.trim();
          } else if (value !== undefined) {
            entite[field] = value;
          }
        }
      }
      await entite.save();
    }

    await logAction({
      user: user._id,
      action: 'UPDATE_PROFILE',
      details: 'Mise à jour du profil connecté',
      ipAddress: req.ip,
    });

    const refreshed = await User.findById(user._id).select('-passwordHash');
    res.json({ message: 'Profil mis à jour', user: refreshed, entite });
  } catch (error) {
    res.status(500).json({ message: 'Erreur mise à jour profil', error: error.message });
  }
});

module.exports = router;
