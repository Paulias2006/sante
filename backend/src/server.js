require('dotenv').config();
const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const { connectDB } = require('./config/database');
const { authenticate } = require('./middleware/auth');
const authRoutes = require('./routes/auth');
const patientRoutes = require('./routes/patients');
const adminRoutes = require('./routes/admin');
const consultationRoutes = require('./routes/consultations');
const ordonnanceRoutes = require('./routes/ordonnances');
const analyseRoutes = require('./routes/analyses');
const rendezVousRoutes = require('./routes/rendezvous');
const pharmacieRoutes = require('./routes/pharmacies');
const inscriptionRoutes = require('./routes/inscription');

const app = express();
const PORT = process.env.PORT || 3000;
const corsOrigin = process.env.CORS_ORIGIN
  ? process.env.CORS_ORIGIN.split(',').map((origin) => origin.trim()).filter(Boolean)
  : true;

app.use(cors({ origin: corsOrigin, credentials: true }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(morgan('dev'));

app.get('/health', (req, res) => {
  res.json({ ok: true, service: 'SantéTogo API', timestamp: new Date().toISOString() });
});

app.use('/api/auth', authRoutes);
app.use('/api/inscription', inscriptionRoutes);
app.use('/api/admin', authenticate, adminRoutes);
app.use('/api/patients', authenticate, patientRoutes);
app.use('/api/consultations', authenticate, consultationRoutes);
app.use('/api/ordonnances', authenticate, ordonnanceRoutes);
app.use('/api/analyses', authenticate, analyseRoutes);
app.use('/api/rendezvous', authenticate, rendezVousRoutes);
app.use('/api/pharmacie', authenticate, pharmacieRoutes);

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ message: 'Erreur interne du serveur', error: err.message });
});
async function startServer() {
  try {
    await connectDB();
    app.listen(PORT, () => {
      console.log(`SantéTogo API listening on port ${PORT}`);
    });
  } catch (error) {
    console.error('Failed to start server:', error.message);
    process.exit(1);
  }
}

startServer();

module.exports = app;
