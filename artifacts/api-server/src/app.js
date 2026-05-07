const express = require('express');
const cors = require('cors');

const authRouter = require('./routes/auth');
const notificationsRouter = require('./routes/notifications');
const adminRouter = require('./routes/admin');

const app = express();

app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

app.get('/api/v1/healthz', (_req, res) => {
  res.json({ status: 'ok', service: 'coopvest-api', version: '1.0.0', timestamp: new Date().toISOString() });
});

app.use('/api/v1/auth', authRouter);
app.use('/api/v1/notifications', notificationsRouter);
app.use('/api/v1/admin', adminRouter);

app.use((_req, res) => {
  res.status(404).json({ error: 'Endpoint not found' });
});

app.use((err, _req, res, _next) => {
  console.error('[ERROR]', err.message || err);
  res.status(500).json({ error: 'Internal server error' });
});

module.exports = app;
