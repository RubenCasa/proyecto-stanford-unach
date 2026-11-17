const L = require('../lib/logica');
const D = require('../data/data.json');
module.exports = (req, res) => {
  res.setHeader('Cache-Control', 'public, s-maxage=300, stale-while-revalidate=3600');
  res.setHeader('Access-Control-Allow-Origin', '*');
  const r = L.tendencia(D, req.query || {});
  res.status(r && r.error ? 404 : 200).json(r);
};
