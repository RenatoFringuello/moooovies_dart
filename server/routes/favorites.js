const express = require('express');
const router = express.Router();
const db = require('../db/database');

// GET /favorites/:deviceId → lista preferiti
router.get('/:deviceId', async (req, res) => {
  const list = await db.getFavorites(req.params.deviceId);
  res.json(list);
});

// POST /favorites → aggiungi preferito
router.post('/', async (req, res) => {
  const { deviceId, movieId } = req.body;
  await db.addFavorite(deviceId, parseInt(movieId));
  res.json({ ok: true });
});

// DELETE /favorites → rimuovi preferito
router.delete('/', async (req, res) => {
  const { deviceId, movieId } = req.body;
  await db.removeFavorite(deviceId, parseInt(movieId));
  res.json({ ok: true });
});

// GET /favorites/:deviceId/:movieId → è preferito?
router.get('/:deviceId/:movieId', async (req, res) => {
  const { deviceId, movieId } = req.params;
  const result = await db.isFavorite(deviceId, parseInt(movieId));
  res.json({ isFavorite: result });
});

module.exports = router;