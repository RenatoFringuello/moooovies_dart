const express = require('express');
const router = express.Router();
const fs = require('fs');
const path = require('path');
const { getCache } = require('../cache');

router.get('/:id', (req, res) => {
  console.log('Richiesta stream per ID:', req.params.id);

  const movies = getCache();
  // console.log('Film in cache:', movies.length);
  // console.log('IDs in cache:', movies.map(m => m.id));

  const movie = movies.find(m => m.id === parseInt(req.params.id));
  // console.log('Film trovato:', JSON.stringify(movie));

  if (!movie) return res.status(404).json({ error: 'Film non trovato' });

  // console.log('local_path:', movie.local_path);

  if (!movie.local_path) {
    return res.status(500).json({ error: 'local_path mancante nel film' });
  }

  const videoPath = path.resolve(movie.local_path);
  if (!fs.existsSync(videoPath)) {
    return res.status(404).json({ error: 'File video non trovato: ' + videoPath });
  }

  const videoSize = fs.statSync(videoPath).size;
  const range = req.headers.range;

  if (!range) {
    res.writeHead(200, {
      'Content-Length': videoSize,
      'Content-Type': 'video/mp4',
    });
    fs.createReadStream(videoPath).pipe(res);
    return;
  }

  const parts = range.replace(/bytes=/, '').split('-');
  const start = parseInt(parts[0], 10);
  const CHUNK_SIZE = 10 ** 6;
  const end = parts[1]
    ? Math.min(parseInt(parts[1], 10), videoSize - 1)
    : Math.min(start + CHUNK_SIZE, videoSize - 1);
  const contentLength = end - start + 1;

  // console.log(`Range: ${start}-${end}/${videoSize}`);

  res.writeHead(206, {
    'Content-Range': `bytes ${start}-${end}/${videoSize}`,
    'Accept-Ranges': 'bytes',
    'Content-Length': contentLength,
    'Content-Type': 'video/mp4',
  });

  fs.createReadStream(videoPath, { start, end }).pipe(res);
});

module.exports = router;