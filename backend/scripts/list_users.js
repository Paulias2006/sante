require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });
const mongoose = require('mongoose');
const User = require('../src/models/User');

async function main() {
  const mongoUri = process.env.MONGODB_URI;

  if (!mongoUri) {
    console.error('MONGODB_URI is missing in backend/.env');
    process.exit(1);
  }

  try {
    await mongoose.connect(mongoUri, {
      serverSelectionTimeoutMS: 20000,
      autoIndex: true,
    });

    const users = await User.find(
      {},
      {
        email: 1,
        role: 1,
        nom: 1,
        prenom: 1,
        actif: 1,
        createdAt: 1,
      }
    ).lean();

    console.log('Total users:', users.length);
    console.log(JSON.stringify(users, null, 2));
  } catch (error) {
    console.error('Erreur de connexion MongoDB');
    console.error(error.message);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
  }
}

main();
