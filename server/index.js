require('dotenv').config();
const express = require('express');
const cors = require('cors');
const moviesRouter = require('./routes/movies');
const streamRouter = require('./routes/stream');
const progressRouter = require('./routes/progress');
const favoritesRouter = require('./routes/favorites');
const { initDb } = require('./db/database');

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());

app.use('/movies', moviesRouter);
app.use('/stream', streamRouter);
app.use('/progress', progressRouter);
app.use('/favorites', favoritesRouter);

// Inizializza DB poi avvia il server
initDb().then(() => {
  app.listen(PORT, '127.0.0.1', () => {
    console.log(`Server avviato su http://127.0.0.1:${PORT}`);
  });
});