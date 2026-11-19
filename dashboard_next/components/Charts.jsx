'use client';
import { useState } from 'react';
import { fmt } from '../lib/util';

/* Escala "redonda" para el eje Y: 4 divisiones con pasos de 1, 2, 2,5, 5 o 10 */
function escalaY(max, min = 0) {
  const g = Math.max((max - min) / 4, 1e-6), e = Math.pow(10, Math.floor(Math.log10(g))), f = g / e;
  const paso = (f <= 1 ? 1 : f <= 2 ? 2 : f <= 2.5 ? 2.5 : f <= 5 ? 5 : 10) * e;
  return { paso, mx: min + paso * 4 };
}

/* Líneas con bandas de rango, línea de "hoy" y lectura al pasar el cursor o tocar. Sin librerías. */
export function LineChart({ x, series, bands = [], h = 300, xlab = [], corte = null, corteTxt = 'pronóstico', yfmt = v => fmt(v), label = 'Gráfico', compact = false, marca = null }) {
  const [hov, setHov] = useState(null);
  const w = compact ? 340 : 760, p = compact ? { l: 34, r: 8, t: 10, b: 22 } : { l: 48, r: 16, t: 16, b: 30 };
  const iw = w - p.l - p.r, ih = h - p.t - p.b, n = x.length;
  const todos = series.flatMap(s => s.y).concat(bands.flatMap(b => b.hi)).filter(v => v != null);
  const { mx } = escalaY(Math.max(...todos, 1) * 1.04);
  const X = i => p.l + (i / (n - 1 || 1)) * iw, Y = v => p.t + ih - (Math.max(0, v) / mx) * ih;
  const path = ys => { let d = ''; ys.forEach((v, i) => { if (v != null) d += `${d && ys[i - 1] != null ? 'L' : 'M'}${X(i).toFixed(1)},${Y(v).toFixed(1)}`; }); return d; };
  const area = b => {
    let up = '', dn = '';
    b.hi.forEach((v, i) => { if (v != null) up += `${up ? 'L' : 'M'}${X(i).toFixed(1)},${Y(v).toFixed(1)}`; });
    for (let i = n - 1; i >= 0; i--) if (b.lo[i] != null) dn += `L${X(i).toFixed(1)},${Y(b.lo[i]).toFixed(1)}`;
    return up ? up + dn + 'Z' : '';
  };
  const mover = e => {
    const r = e.currentTarget.getBoundingClientRect(), fx = (e.clientX - r.left) / r.width;
    const sx = (fx * w - p.l) / iw;
    setHov({ i: Math.max(0, Math.min(n - 1, Math.round(sx * (n - 1)))), left: fx * 100 });
  };
  return (
    <div className="chart" onPointerMove={mover} onPointerLeave={() => setHov(null)}>
      <svg viewBox={`0 0 ${w} ${h}`} width="100%" role="img" aria-label={label}>
        {[0, 1, 2, 3, 4].map(k => { const v = (mx * k) / 4, y = Y(v); return (
          <g key={k}><line x1={p.l} x2={w - p.r} y1={y} y2={y} className={k ? 'gl' : 'gl0'} /><text x={p.l - 8} y={y + 4} textAnchor="end" className="ax">{yfmt(v)}</text></g>); })}
        {xlab.map(([i, t]) => <text key={i} x={X(i)} y={h - 8} textAnchor="middle" className="ax">{t}</text>)}
        {corte != null && corte > 0 && <rect x={X(corte - 1)} y={p.t} width={Math.max(0, X(n - 1) - X(corte - 1))} height={ih} className="fut" />}
        {bands.map((b, k) => <path key={k} d={area(b)} style={{ fill: b.c }} opacity={b.o} />)}
        {corte != null && corte > 0 && !compact && <text x={X(corte - 1) + 8} y={p.t + 14} className="ax fut-t">{corteTxt} →</text>}
        {series.map(s => <path key={s.n} d={path(s.y)} fill="none" style={{ stroke: s.c }} strokeWidth={s.w || (compact ? 2 : 2.25)} strokeDasharray={s.dash ? '5 5' : undefined} strokeLinejoin="round" strokeLinecap="round" />)}
        {hov && <line x1={X(hov.i)} x2={X(hov.i)} y1={p.t} y2={p.t + ih} className="cur" />}
        {hov && series.map(s => s.y[hov.i] != null && <circle key={s.n} cx={X(hov.i)} cy={Y(s.y[hov.i])} r="4.5" style={{ fill: s.c }} className="dot" />)}
        {marca != null && series[marca.s] && series[marca.s].y[marca.i] != null && <circle cx={X(marca.i)} cy={Y(series[marca.s].y[marca.i])} r="6" className="mk" />}
      </svg>
      {hov && series.some(s => s.y[hov.i] != null) && (
        <div className="tip" style={{ left: `${hov.left}%`, transform: `translateX(${hov.left > 60 ? 'calc(-100% - 12px)' : '12px'})` }}>
          <b>{x[hov.i]}</b>
          {series.map(s => s.y[hov.i] != null && <div key={s.n}><i style={{ background: s.c }} />{s.n}: <b>{yfmt(s.y[hov.i])}</b></div>)}
          {bands.length > 0 && bands[bands.length - 1].hi[hov.i] != null && <div className="mut">Rango probable: {yfmt(bands[bands.length - 1].lo[hov.i])} – {yfmt(bands[bands.length - 1].hi[hov.i])}</div>}
        </div>
      )}
    </div>
  );
}

/* Columnas verticales con valor encima */
export function Columnas({ items, h = 220, color = 'var(--acc)', yfmt = v => fmt(v), label = 'Gráfico de columnas' }) {
  const [hov, setHov] = useState(null);
  const w = 520, p = { l: 8, r: 8, t: 22, b: 26 }, iw = w - p.l - p.r, ih = h - p.t - p.b;
  const mx = Math.max(...items.map(i => i.v), 1), bw = iw / items.length;
  return (
    <svg viewBox={`0 0 ${w} ${h}`} width="100%" role="img" aria-label={label} className="chart">
      <line x1={p.l} x2={w - p.r} y1={p.t + ih} y2={p.t + ih} className="gl0" />
      {items.map((it, i) => { const bh = (it.v / mx) * ih, x0 = p.l + i * bw + bw * 0.16, on = hov == null || hov === i; return (
        <g key={i} onPointerEnter={() => setHov(i)} onPointerLeave={() => setHov(null)}>
          <rect x={p.l + i * bw} y={p.t} width={bw} height={ih + p.b} fill="transparent" />
          <rect x={x0} y={p.t + ih - bh} width={bw * 0.68} height={Math.max(bh, 1)} rx="3" style={{ fill: it.c || color }} opacity={on ? 1 : 0.45} />
          <text x={x0 + bw * 0.34} y={p.t + ih - bh - 6} textAnchor="middle" className="ax val" opacity={on ? 1 : 0.5}>{yfmt(it.v)}</text>
          <text x={x0 + bw * 0.34} y={h - 8} textAnchor="middle" className="ax">{it.l || it.n}</text>
        </g>); })}
    </svg>
  );
}

/* Barras horizontales con nombre a la izquierda y valor a la derecha */
export function Barras({ items, color = 'var(--acc)', fmtv = v => fmt(v), max, onClick }) {
  const m = max || Math.max(...items.map(i => Math.abs(i.v)), 1);
  return (
    <div className="barras">{items.map((i, k) => {
      const Tag = onClick ? 'button' : 'div';
      return (
        <Tag className="barra" key={k} onClick={onClick ? () => onClick(i) : undefined}>
          <span className="nm">{i.n}</span>
          <span className="tr"><span className="fi" style={{ width: `${Math.max(1.5, (Math.abs(i.v) / m) * 100)}%`, background: i.c || color }} /></span>
          <span className="nu">{i.txt || fmtv(i.v)}</span>
        </Tag>); })}</div>
  );
}
