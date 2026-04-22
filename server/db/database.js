const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
});

// Inizializza le tabelle
async function initDb() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS watch_progress (
      device_id   TEXT NOT NULL,
      movie_id    INTEGER NOT NULL,
      position_ms BIGINT NOT NULL DEFAULT 0,
      duration_ms BIGINT NOT NULL DEFAULT 0,
      last_watched TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (device_id, movie_id)
    );

    CREATE TABLE IF NOT EXISTS favorites (
      device_id TEXT NOT NULL,
      movie_id  INTEGER NOT NULL,
      added_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      PRIMARY KEY (device_id, movie_id)
    );
  `);
  console.log('Database inizializzato');
}

// ── PROGRESS ──────────────────────────────────────────

async function saveProgress(deviceId, movieId, positionMs, durationMs) {
  await pool.query(`
    INSERT INTO watch_progress (device_id, movie_id, position_ms, duration_ms, last_watched)
    VALUES ($1, $2, $3, $4, NOW())
    ON CONFLICT (device_id, movie_id) DO UPDATE SET
      position_ms  = EXCLUDED.position_ms,
      duration_ms  = EXCLUDED.duration_ms,
      last_watched = NOW()
  `, [deviceId, movieId, positionMs, durationMs]);
}

async function getProgress(deviceId, movieId) {
  const result = await pool.query(`
    SELECT * FROM watch_progress WHERE device_id = $1 AND movie_id = $2
  `, [deviceId, movieId]);
  return result.rows[0] ?? null;
}

async function getContinueWatching(deviceId) {
  const result = await pool.query(`
    SELECT * FROM watch_progress
    WHERE device_id = $1
      AND position_ms > 0
      AND position_ms < duration_ms * 0.95
    ORDER BY last_watched DESC
  `, [deviceId]);
  return result.rows;
}

// ── FAVORITES ─────────────────────────────────────────

async function addFavorite(deviceId, movieId) {
  await pool.query(`
    INSERT INTO favorites (device_id, movie_id, added_at)
    VALUES ($1, $2, NOW())
    ON CONFLICT DO NOTHING
  `, [deviceId, movieId]);
}

async function removeFavorite(deviceId, movieId) {
  await pool.query(`
    DELETE FROM favorites WHERE device_id = $1 AND movie_id = $2
  `, [deviceId, movieId]);
}

async function getFavorites(deviceId) {
  const result = await pool.query(`
    SELECT * FROM favorites WHERE device_id = $1 ORDER BY added_at DESC
  `, [deviceId]);
  return result.rows;
}

async function isFavorite(deviceId, movieId) {
  const result = await pool.query(`
    SELECT 1 FROM favorites WHERE device_id = $1 AND movie_id = $2
  `, [deviceId, movieId]);
  return result.rows.length > 0;
}

async function deleteProgress(deviceId, movieId) {
  await pool.query(
    'DELETE FROM watch_progress WHERE device_id = $1 AND movie_id = $2',
    [deviceId, movieId]
  );
}

module.exports = {
  initDb,
  saveProgress,
  getProgress,
  getContinueWatching,
  addFavorite,
  removeFavorite,
  getFavorites,
  isFavorite,
  deleteProgress,
};