const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');
const fetch = (...args) => import('node-fetch').then(({default: f}) => f(...args));

const FILMS_DIR = process.env.FILMS_DIR;
const TMDB_API_KEY = process.env.TMDB_API_KEY;
const TMDB_BASE_URL = 'https://api.themoviedb.org/3';

// Cache in memoria
const { getCache, setCache } = require('../cache');
// e ovunque usi moviesCache usa getCache()/setCache()
let lastScan = null;

// Parsa "nome_film_anno.mp4" → { title: "nome film", year: "anno" }
function parseFilename(filename) {
  const noExt = path.basename(filename, path.extname(filename));
  const match = noExt.match(/^(.+?)_(\d{4})$/);
  if (match) {
    return {
      title: match[1].replace(/_/g, ' ').trim(),
      year: match[2],
    };
  }
  // fallback senza anno
  return {
    title: noExt.replace(/_/g, ' ').trim(),
    year: null,
  };
}

// Cerca film su TMDB
async function searchTmdb(title, year) {
  try {
    const query = encodeURIComponent(title);
    const yearParam = year ? `&year=${year}` : '';
    const url = `${TMDB_BASE_URL}/search/movie?api_key=${TMDB_API_KEY}&query=${query}${yearParam}&language=it-IT`;
    const res = await fetch(url);
    const data = await res.json();
    if (data.results && data.results.length > 0) {
      return data.results[0];
    }
  } catch (e) {
    console.error(`Errore TMDB per "${title}":`, e.message);
  }
  return null;
}

// Scansiona la cartella e costruisce la lista film
async function scanFilms() {
  //console.log('Scansione cartella:', FILMS_DIR);

  const files = fs.readdirSync(FILMS_DIR).filter(f =>
    ['.mp4', '.mkv', '.avi', '.mov'].includes(path.extname(f).toLowerCase())
  );

  console.log(`Trovati ${files.length} film`);

  const movies = [];

  for (const file of files) {
    const { title, year } = parseFilename(file);
    //console.log(`Cerco su TMDB: "${title}" (${year ?? 'anno sconosciuto'})`);

    const tmdb = await searchTmdb(title, year);

    movies.push({
      id: tmdb?.id ?? Math.random(),
      title: tmdb?.title ?? title,
      original_title: tmdb?.original_title ?? '',
      poster_path: tmdb?.poster_path ?? '',
      backdrop_path: tmdb?.backdrop_path ?? '',
      overview: tmdb?.overview ?? '',
      release_date: tmdb?.release_date ?? year ?? '',
      vote_average: tmdb?.vote_average ?? 0,
      vote_count: tmdb?.vote_count ?? 0,
      original_language: tmdb?.original_language ?? '',
      genre_ids: tmdb?.genre_ids ?? [],
      popularity: tmdb?.popularity ?? 0,
      local_path: path.join(FILMS_DIR, file),
    });
  }

  setCache(movies);
  lastScan = new Date();
  console.log(`Scansione completata: ${movies.length}/${files.length} film trovati`);
  return movies;
}

// Scansione automatica all'avvio
scanFilms();

// GET /movies → lista completa (dalla cache)
router.get('/', async (req, res) => {
  const moviesCache = getCache();
  if (moviesCache.length === 0) {
    await scanFilms();
  }
  res.json(moviesCache);
});

// GET /movies/scan → forza refresh manuale
router.get('/scan', async (req, res) => {
  const movies = await scanFilms();
  res.json({ message: `Scansione completata: ${movies.length} film trovati`, movies });
});

// GET /movies/:id → singolo film
router.get('/:id', (req, res) => {
  const moviesCache = getCache();
  const movie = moviesCache.find(m => m.id === parseInt(req.params.id));
  if (!movie) return res.status(404).json({ error: 'Film non trovato' });
  res.json(movie);
});

module.exports = router;