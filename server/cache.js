let moviesCache = [];

module.exports = {
  getCache: () => moviesCache,
  setCache: (movies) => { moviesCache = movies; },
};