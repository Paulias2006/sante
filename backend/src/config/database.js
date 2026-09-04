const mongoose = require('mongoose');
const dns = require('dns');

// Force public DNS resolvers when the system DNS is broken or intercepts MongoDB SRV lookups.
dns.setServers(['1.1.1.1', '8.8.8.8']);

async function connectDB() {
  const mongoUri = process.env.MONGODB_URI;

  if (!mongoUri) {
    throw new Error('MONGODB_URI is required');
  }

  mongoose.set('strictQuery', true);

  await mongoose.connect(mongoUri, {
    autoIndex: true,
    serverSelectionTimeoutMS: 30000,
  });
  console.log('MongoDB connected successfully');
}

module.exports = { connectDB };
