'use client';
import { useState } from 'react';
import { fmt } from '../lib/util';

/* Gráfico de líneas con bandas, línea de corte (pronóstico) y tooltip. Sin librerías externas. */
export function LineChart({ x, series, bands = [], h = 300, xlab = [], corte = null, yfmt = v => fmt(v), ymin = 0, compact = false }) {
  const [hov, setHov] = useState(null);
  const w = compact ? 300 : 760, p = compact ? { l: 30, r: 6, t: 8, b: 6 } : { l: 46, r: 14, t: 12, b: 30 };
  const iw = w - p.l - p.r, ih = h - p.t - p.b, n = x.length;
  const todos = series.flatMap(s => s.y).concat(bands.flatMap(b => b.hi)).filter(v => v != null);
  const mxRaw = Math.max(...todos, 1) * 1.05, mn = ymin;
  const paso = (() => { const g = (mxRaw - mn) / 4, e = Math.pow(10, Math.floor(Math.log10(g))), f = g / e; return (f <= 1 ? 1 : f <= 2 ? 2 : f <= 2.5 ? 2.5 : f <= 5 ? 5 : 10) * e; })();
  const mx = mn + paso * 4;
  const X = i => p.l + (i / (n - 1 || 1)) * iw, Y = v => p.t + ih - ((v - mn) / (mx - mn)) * ih;
  const path = ys => { let d = ''; ys.forEach((v, i) => { if (v != null) d += `${d && ys[i - 1] != null ? 'L' : 'M'}${X(i).toFixed(1)},${Y(v).toFixed(1)}`; }); return d; };
  const area = b => {
    let up = '', dn = '';
    b.hi.forEach((v, i) => { if (v != null) up += `${up ? 'L' : 'M'}${X(i).toFixed(1)},${Y(v).toFixed(1)}`; });
    for (let i = n - 1; i >= 0; i--) if (b.lo[i] != null) dn += `L${X(i).toFixed(1)},${Y(Math.max(0, b.lo[i])).toFixed(1)}`;
    return up + dn + 'Z';
  };
  const mover = e => {
    const r = e.currentTarget.getBoundingClientRect();
    const i = Math.max(0, Math.min(n - 1, Math.round(((e.clientX - r.left) / r.width) * (n - 1))));
    setHov({ i, left: ((e.clientX - r.left) / r.width) * 100 });
  };
  return (
    <div style={{ position: 'relative' }}>
      <svg viewBox={`0 0 ${w} ${h}`} width="100%" role="img">
        {[0, 1, 2, 3, 4].map(k => { const v = mn + ((mx - mn) * k) / 4, y = Y(v); return (
          <g key={k}><line x1={p.l} x2={w - p.r} y1={y} y2={y} stroke="var(--grid)" /><text x={p.l - 6} y={y + 4} textAnchor="end" fontSize={compact ? 9 : 11} fill="var(--mut)">{yfmt(v)}</text></g>); })}
        {xlab.map(([i, t]) => <text key={i} x={X(i)} y={h - 8} textAnchor="middle" fontSize="11" fill="var(--mut)">{t}</text>)}
        {bands.map((b, k) => <path key={k} d={area(b)} fill={b.c} opacity={b.o} />)}
        {corte != null && corte > 0 && (<g><line x1={X(corte)} x2={X(corte)} y1={p.t} y2={p.t + ih} stroke="var(--mut)" strokeDasharray="4 4" opacity=".6" />
          {!compact && <text x={X(corte) + 6} y={p.t + 12} fontSize="11" fill="var(--mut)">pronóstico →</text>}</g>)}
        {series.map(s => <path key={s.n} d={path(s.y)} fill="none" stroke={s.c} strokeWidth={compact ? 2 : 2.4} strokeDasharray={s.dash ? '6 5' : undefined} strokeLinejoin="round" />)}
        {hov && <line x1={X(hov.i)} x2={X(hov.i)} y1={p.t} y2={p.t + ih} stroke="var(--ink)" strokeOpacity=".3" />}
        {hov && series.map(s => s.y[hov.i] != null && <circle key={s.n} cx={X(hov.i)} cy={Y(s.y[hov.i])} r="4" fill={s.c} stroke="#fff" strokeWidth="1.5" />)}
        <rect x={p.l} y={p.t} width={iw} height={ih} fill="transparent" onMouseMove={mover} onMouseLeave={() => setHov(null)} />
      </svg>
      {hov && (
        <div className="tip2" style={{ left: `${Math.min(hov.left, 78)}%`, top: 6 }}>
          <b>{x[hov.i]}</b>
          {series.map(s => s.y[hov.i] != null && <div key={s.n}><i style={{ background: s.c }} />{s.n}: <b>{yfmt(s.y[hov.i])}</b></div>)}
          {bands[1] && bands[1].hi[hov.i] != null && <div className="mut">Rango 80 %: {yfmt(bands[1].lo[hov.i])} – {yfmt(bands[1].hi[hov.i])}</div>}
        </div>
      )}
    </div>
  );
}

export function Columnas({ items, h = 230, color = '#1f6fb2', yfmt = v => fmt(v, 1) }) {
  const [hov, setHov] = useState(null);
  const w = 520, p = { l: 34, r: 8, t: 10, b: 28 }, iw = w - p.l - p.r, ih = h - p.t - p.b;
  const mx = Math.max(...items.map(i => i.v), 1) * 1.15, bw = iw / items.length;
  return (
    <div style={{ position: 'relative' }}>
      <svg viewBox={`0 0 ${w} ${h}`} width="100%">
        {[0, 1, 2, 3].map(k => { const v = (mx * k) / 3, y = p.t + ih - (v / mx) * ih; return (
          <g key={k}><line x1={p.l} x2={w - p.r} y1={y} y2={y} stroke="var(--grid)" /><text x={p.l - 6} y={y + 4} textAnchor="end" fontSize="10.5" fill="var(--mut)">{yfmt(v)}</text></g>); })}
        {items.map((it, i) => { const bh = (it.v / mx) * ih, x0 = p.l + i * bw + bw * 0.18; return (
          <g key={i} onMouseEnter={() => setHov(i)} onMouseLeave={() => setHov(null)}>
            <rect x={x0} y={p.t + ih - bh} width={bw * 0.64} height={bh} rx="4" fill={it.c || color} opacity={hov == null || hov === i ? 1 : 0.55} style={{ transition: 'opacity .15s' }} />
            <text x={x0 + bw * 0.32} y={h - 9} textAnchor="middle" fontSize="10.5" fill="var(--mut)">{it.l || it.n}</text>
          </g>); })}
      </svg>
      {hov != null && <div className="tip2" style={{ left: `${((p.l + hov * bw + bw / 2) / w) * 100}%`, top: 0, transform: 'translateX(-50%)' }}><b>{items[hov].n}</b><div>{yfmt(items[hov].v)}</div></div>}
    </div>
  );
}

export function Barras({ items, color = '#1f6fb2', fmtv = v => fmt(v), max }) {
  const m = max || Math.max(...items.map(i => i.v), 1);
  return (
    <div>{items.map((i, k) => (
      <div className="bar" key={k}>
        <span className="nm">{i.n}</span>
        <span className="tr"><span className="fi" style={{ width: `${Math.max(1, (i.v / m) * 100)}%`, background: i.c || color }} /></span>
        <span className="nu">{fmtv(i.v)}</span>
      </div>))}</div>
  );
}
