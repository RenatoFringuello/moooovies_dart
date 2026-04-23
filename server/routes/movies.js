const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');
const fetch = (...args) => import('node-fetch').then(({default: f}) => f(...args));

const FILMS_DIR = process.env.FILMS_DIR;
const TMDB_API_KEY = process.env.TMDB_API_KEY;
const TMDB_BASE_URL = 'https://api.themoviedb.org/3';

const { getCache, setCache } = require('../cache');
let lastScan = null;

function parseFilename(filename) {
  const noExt = path.basename(filename, path.extname(filename));
  const match = noExt.match(/^(.+?)_(\d{4})$/);
  if (match) {
    return { title: match[1].replace(/_/g, ' ').trim(), year: match[2] };
  }
  return { title: noExt.replace(/_/g, ' ').trim(), year: null };
}

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function searchTmdb(title, year) {
  try {
    const query = encodeURIComponent(title);
    const yearParam = year ? `&year=${year}` : '';
    const url = `${TMDB_BASE_URL}/search/movie?api_key=${TMDB_API_KEY}&query=${query}${yearParam}&language=it-IT`;
    const res = await fetch(url);
    const data = await res.json();
    if (data.results && data.results.length > 0) return data.results[0];
  } catch (e) {
    console.error(`Errore TMDB per "${title}":`, e.message);
  }
  return null;
}

async function fetchCredits(movieId) {
  try {
    const url = `${TMDB_BASE_URL}/movie/${movieId}/credits?api_key=${TMDB_API_KEY}&language=it-IT`;
    const res = await fetch(url);
    const data = await res.json();
    const castNames = (data.cast || []).slice(0, 10).map(a => a.name.toLowerCase());
    const crewNames = (data.crew || [])
      .filter(c => c.job === 'Director')
      .map(d => d.name.toLowerCase());
    return { castNames, crewNames };
  } catch (e) {
    console.error(`Errore credits per movie ${movieId}:`, e.message);
    return { castNames: [], crewNames: [] };
  }
}

async function scanFilms() {
  console.log('Scansione cartella:', FILMS_DIR);
  const files = fs.readdirSync(FILMS_DIR).filter(f =>
    ['.mp4', '.mkv', '.avi', '.mov'].includes(path.extname(f).toLowerCase())
  );
  console.log(`Trovati ${files.length} file video`);

  const movies = [];

  for (const file of files) {
    const { title, year } = parseFilename(file);
    //console.log(`Cerco su TMDB: "${title}" (${year ?? 'anno sconosciuto'})`);
    const tmdb = await searchTmdb(title, year);

    let castNames = [];
    let crewNames = [];

    if (tmdb?.id) {
      await sleep(300);
      const credits = await fetchCredits(tmdb.id);
      castNames = credits.castNames;
      crewNames = credits.crewNames;
    }

    movies.push({
      id: tmdb?.id ?? Math.floor(Math.random() * 100000),
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
      cast_names: castNames,
      crew_names: crewNames,
      local_path: path.join(FILMS_DIR, file),
    });
  }

  setCache(movies);
  lastScan = new Date();
  console.log(`Scansione completata: ${movies.length}/${files.length} film trovati`);
  return movies;
}

scanFilms();

router.get('/', async (req, res) => {
  const moviesCache = getCache();
  if (moviesCache.length === 0) await scanFilms();
  res.json(getCache());
});

router.get('/scan', async (req, res) => {
  const movies = await scanFilms();
  res.json({ message: `Scansione completata: ${movies.length} film trovati`, movies });
});

router.get('/:id', (req, res) => {
  const moviesCache = getCache();
  const movie = moviesCache.find(m => m.id === parseInt(req.params.id));
  if (!movie) return res.status(404).json({ error: 'Film non trovato' });
  res.json(movie);
});

module.exports = router;