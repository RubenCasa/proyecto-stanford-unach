/* Lógica compartida: la usan las funciones /api (servidor) y el navegador (respaldo sin internet). */
(function (root) {
  const L = {};
  const num = (v, d) => (v === undefined || v === '' || isNaN(+v) ? d : +v);
  L.alerta = (indice, umbral) => (indice >= 100 + umbral ? 'Alta' : indice >= 100 + umbral / 2 ? 'Media' : 'Normal');
  L.roll12 = arr => arr.map((_, i) => (i < 11 ? null : arr.slice(i - 11, i + 1).reduce((a, b) => a + (b || 0), 0)));

  L.datos = D => D;

  L.pronostico = (D, q = {}) => {
    const umbral = num(q.umbral, 25), h = num(q.horizonte, 0);
    const src = (q.esc && D.esc && D.esc.pron && D.esc.pron[q.esc]) || D.pron;
    const filas = src.filter(p => !h || p.horizonte === h).map(p => ({ ...p, alerta: L.alerta(p.indice, umbral) }));
    return { umbral, filas, altas: filas.filter(p => p.horizonte === 1 && p.alerta === 'Alta').map(p => p.parroquia_corta) };
  };

  L.tendencia = (D, q = {}) => {
    const p = (q.parroquia || 'RIOBAMBA').toUpperCase();
    const serie = D.mensual[p];
    if (!serie) return { error: 'parroquia no encontrada', disponibles: Object.keys(D.mensual) };
    return { parroquia: p, serie, acum12: L.roll12(serie.inc) };
  };

  /* Matriz mes × parroquia: delitos de los 12 meses que terminan en cada mes, y por km² */
  L.mapa = D => {
    const area = Object.fromEntries(D.geo.map(g => [g.nom, g.area]));
    const meses = D.mensual.RIOBAMBA.mes, out = {};
    Object.keys(D.mensual).forEach(n => {
      const m = D.mensual[n], suma = L.roll12(m.inc.map(v => v || 0));
      out[n] = { suma, km2: suma.map(v => (v == null ? null : +(v / area[n]).toFixed(3))),
                 fc: m.tipo.map(t => t === 'Pronóstico') };
    });
    return { meses, parroquias: out };
  };

  L.resumen = D => {
    const c1 = D.codigo.find(c => c.codigo_coip === 1), yrs = ['2022', '2023', '2024', '2025', '2026', '2027', '2028', '2029'];
    const total = yrs.map(y => D.cambio.reduce((s, r) => s + (r[y] || 0), 0));
    return { delitos_coip: c1.registros, pct: c1.pct, anios: yrs, total_por_anio: total };
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = L; else root.LOGICA = L;
})(typeof window !== 'undefined' ? window : this);
