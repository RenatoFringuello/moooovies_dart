const express = require('express');
const router = express.Router();
const db = require('../db/database');

router.post('/', async (req, res) => {
  const { deviceId, movieId, positionMs, durationMs } = req.body;
  if (!deviceId || !movieId) {
    return res.status(400).json({ error: 'deviceId e movieId obbligatori' });
  }
  await db.saveProgress(deviceId, movieId, positionMs, durationMs);
  res.json({ ok: true });
});

router.get('/:deviceId/:movieId', async (req, res) => {
  const { deviceId, movieId } = req.params;
  const progress = await db.getProgress(deviceId, parseInt(movieId));
  res.json(progress ?? { position_ms: 0, duration_ms: 0 });
});

router.get('/:deviceId', async (req, res) => {
  const list = await db.getContinueWatching(req.params.deviceId);
  res.json(list);
});

router.delete('/', async (req, res) => {
  const { deviceId, movieId } = req.body;
  await db.deleteProgress(deviceId, parseInt(movieId));
  res.json({ ok: true });
});

module.exports = router;