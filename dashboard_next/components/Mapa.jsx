'use client';
import { useMemo, useState } from 'react';
import { nom } from '../lib/util';

/* Centroide (por área) del anillo exterior más grande de una parroquia */
function centro(poly) {
  let best = null, bestA = 0;
  poly.forEach(pl => {
    const r = pl[0]; let a = 0, cx = 0, cy = 0;
    for (let i = 0, j = r.length - 1; i < r.length; j = i++) {
      const f = r[j][0] * r[i][1] - r[i][0] * r[j][1];
      a += f; cx += (r[j][0] + r[i][0]) * f; cy += (r[j][1] + r[i][1]) * f;
    }
    if (Math.abs(a) > bestA) { bestA = Math.abs(a); best = [cx / (3 * a), cy / (3 * a)]; }
  });
  return best;
}
/* Ajustes de etiqueta para parroquias pequeñas o con forma irregular */
const AJUSTE = { CUBIJIES: [34, -30], RIOBAMBA: [-2, 10], LICAN: [4, -24], CALPI: [-16, 10] };

/* Mapa de las 12 parroquias. color(n) → color de relleno; etiqueta(n) → texto corto bajo el nombre. */
export default function Mapa({ geo, color, etiqueta, sel, onSel, alto = 460 }) {
  const [hov, setHov] = useState(null);
  const G = useMemo(() => {
    let x0 = 1e9, x1 = -1e9, y0 = 1e9, y1 = -1e9;
    geo.forEach(f => f.poly.forEach(pl => pl[0].forEach(([a, b]) => { x0 = Math.min(x0, a); x1 = Math.max(x1, a); y0 = Math.min(y0, b); y1 = Math.max(y1, b); })));
    const k = Math.cos((-1.7 * Math.PI) / 180), W = 600, pad = 14;
    const H = ((W - 2 * pad) * (y1 - y0)) / ((x1 - x0) * k) + 2 * pad;
    const X = a => pad + ((a - x0) / (x1 - x0)) * (W - 2 * pad), Y = b => H - pad - ((b - y0) / (y1 - y0)) * (H - 2 * pad);
    const feats = geo.map(f => {
      const d = f.poly.map(pl => pl.map(r => 'M' + r.map(([a, b]) => `${X(a).toFixed(1)},${Y(b).toFixed(1)}`).join('L') + 'Z').join('')).join('');
      const c = centro(f.poly), aj = AJUSTE[f.nom] || [0, 0];
      return { ...f, d, cx: X(c[0]) + aj[0], cy: Y(c[1]) + aj[1] };
    });
    return { W, H, feats };
  }, [geo]);
  const activo = hov || sel;
  return (
    <div className="mapa" style={{ '--alto': alto + 'px' }}>
      <svg viewBox={`0 0 ${G.W} ${G.H}`} role="img" aria-label="Mapa de las parroquias del cantón Riobamba">
        {G.feats.map(f => (
          <path key={f.nom} d={f.d} style={{ fill: color(f.nom) }} className={`pq ${f.foco ? 'foco' : ''} ${sel === f.nom ? 'sel' : ''} ${activo && activo !== f.nom ? 'dim' : ''}`}
            tabIndex={0} role="button" aria-label={`${nom(f.nom)}${etiqueta ? ': ' + etiqueta(f.nom) : ''}`}
            onPointerEnter={() => setHov(f.nom)} onPointerLeave={() => setHov(null)} onFocus={() => setHov(f.nom)} onBlur={() => setHov(null)}
            onClick={() => onSel(f.nom)} onKeyDown={e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); onSel(f.nom); } }} />
        ))}
        {G.feats.map(f => (
          <g key={f.nom} className={`et ${activo === f.nom ? 'on' : ''}`} transform={`translate(${f.cx.toFixed(1)},${f.cy.toFixed(1)})`} aria-hidden="true">
            <text className="et-n" y={etiqueta ? -2 : 4}>{nom(f.nom)}</text>
            {etiqueta && <text className="et-v" y={17}>{etiqueta(f.nom)}</text>}
          </g>
        ))}
      </svg>
    </div>
  );
}
