'use client';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import dynamic from 'next/dynamic';
import { Barras, Columnas, LineChart } from './Charts';
import { api } from '../lib/api';
import { COL, FOCO, PAL, carita, fmt, mesTxt, nom, ruido, semana } from '../lib/util';

const MapaVivo = dynamic(() => import('./MapaVivo'), { ssr: false, loading: () => <div className="card" style={{ height: 500, display: 'grid', placeItems: 'center' }}>Cargando mapa…</div> });

const ICO = { conf: 'M12 2l9 4v6c0 5-3.8 9.7-9 10-5.2-.3-9-5-9-10V6l9-4zm-1 13l6-6-1.4-1.4L11 12.2 8.4 9.6 7 11l4 4z', esc: 'M3 6h18v2H3zm4 5h10v2H7zm3 5h4v2h-4z', inicio: 'M3 13h8V3H3zm0 8h8v-6H3zm10 0h8V11h-8zm0-18v6h8V3z', mapa: 'M20.5 3l-6 2-5-2-6 2v16l6-2 5 2 6-2zM9 5.5l5 1.7v11.3l-5-1.7z', pron: 'M12 2l3 7h7l-5.5 4.5L18 21l-6-4-6 4 1.5-7.5L2 9h7z', tend: 'M3 17l6-6 4 4 8-8v6h2V3h-10v2h6l-6 6-4-4-8 8z', modelos: 'M12 3l9 4.5v9L12 21l-9-4.5v-9zm0 2.2L5.5 8.4 12 11.6l6.5-3.2z', abig: 'M4 20h16v-2H4zM6 8l3-4 3 4 3-4 3 4v8H6z', metodo: 'M12 2a10 10 0 100 20 10 10 0 000-20zm1 15h-2v-6h2zm0-8h-2V7h2z' };
const SECC = [['inicio', 'Inicio'], ['mapa', 'Mapa'], ['pron', 'Pronóstico'], ['conf', 'Confianza y definiciones']];
const ALIAS = { tend: 'pron', modelos: 'conf', esc: 'conf', abig: 'conf', metodo: 'conf' };
const YRS = ['2022', '2023', '2024', '2025', '2026', '2027', '2028', '2029'];
const Badge = ({ a }) => <span className={`badge b-${a}`}>{a}</span>;
function Cuenta({ n, dec = 0, suf = '' }) {
  const [v, setV] = useState(0);
  useEffect(() => { let id; const t0 = performance.now(); const f = t => { const k = Math.min(1, (t - t0) / 900); setV(n * (1 - Math.pow(1 - k, 3))); if (k < 1) id = requestAnimationFrame(f); }; id = requestAnimationFrame(f); return () => cancelAnimationFrame(id); }, [n]);
  return <>{fmt(v, dec)}{suf}</>;
}

/* Medidor semicircular de probabilidad (0–100 %) */
function Medidor({ pct, size = 150 }) {
  const col = '#1f6fb2'; // azul neutro: la probabilidad de que ocurra un delito no es, por sí sola, una alerta
  const a = Math.PI * (1 - Math.min(100, pct) / 100), R = 60, cx = 75, cy = 72;
  const px = cx + R * Math.cos(a), py = cy - R * Math.sin(a);
  return (
    <svg viewBox="0 0 150 92" width={size} role="img" aria-label={`Probabilidad ${pct} %`}>
      <path d={`M${cx - R},${cy} A${R},${R} 0 0 1 ${cx + R},${cy}`} fill="none" stroke="var(--grid)" strokeWidth="13" strokeLinecap="round" />
      {pct > 0 && <path d={`M${cx - R},${cy} A${R},${R} 0 0 1 ${px.toFixed(1)},${py.toFixed(1)}`} fill="none" stroke={col} strokeWidth="13" strokeLinecap="round" />}
      <text x={cx} y={cy - 6} textAnchor="middle" fontSize="26" fontWeight="800" fill="var(--ink)">{pct}%</text>
      <text x={cx} y={cy + 12} textAnchor="middle" fontSize="9.5" fill="var(--mut)">de probabilidad</text>
    </svg>
  );
}
const nivel = p => (p < 20 ? ['poco probable', 'Normal'] : p < 60 ? ['posible', 'Media'] : ['muy probable', 'Alta']);

/* Mapa rápido (SVG) para el inicio: parroquias coloreadas por alerta, clic = abrir en el mapa grande */
function MiniMapa({ D, p1, onSel }) {
  const g = D.geo; let x0 = 1e9, x1 = -1e9, y0 = 1e9, y1 = -1e9;
  g.forEach(f => f.poly.forEach(pl => pl[0].forEach(([a, b]) => { x0 = Math.min(x0, a); x1 = Math.max(x1, a); y0 = Math.min(y0, b); y1 = Math.max(y1, b); })));
  const W = 420, k = Math.cos((-1.7 * Math.PI) / 180), H = (W * (y1 - y0)) / ((x1 - x0) * k);
  const X = a => ((a - x0) / (x1 - x0)) * W, Y = b => H - ((b - y0) / (y1 - y0)) * H;
  const [hov, setHov] = useState(null);
  return (
    <div style={{ position: 'relative' }}>
      <svg viewBox={`0 0 ${W} ${H}`} width="100%">
        {g.map(f => { const p = p1.find(q => q.parroquia_corta === f.nom); const d = f.poly.map(pl => pl.map(r => 'M' + r.map(([a, b]) => `${X(a).toFixed(1)},${Y(b).toFixed(1)}`).join('L') + 'Z').join('')).join('');
          return <path key={f.nom} d={d} fill={p ? COL[p.alerta] : '#ccc'} fillOpacity={hov && hov !== f.nom ? 0.45 : 0.9} stroke={f.foco ? '#0b1b2b' : '#fff'} strokeWidth={f.foco ? 2.2 : 1} strokeDasharray={f.foco ? '5 3' : undefined} strokeLinejoin="round" style={{ cursor: 'pointer', transition: 'fill-opacity .15s' }} onMouseEnter={() => setHov(f.nom)} onMouseLeave={() => setHov(null)} onClick={() => onSel(f.nom)} />; })}
      </svg>
      <div className="mm-tip">{hov ? <><b>{nom(hov)}</b> · alerta {p1.find(q => q.parroquia_corta === hov)?.alerta.toLowerCase()}</> : 'Pasa el cursor o toca una parroquia'}</div>
      <div className="leg"><span><i style={{ background: COL.Normal }} />Normal</span><span><i style={{ background: COL.Media }} />Atención</span><span><i style={{ background: COL.Alta }} />Alerta</span><span>┅ ★ foco</span></div>
    </div>
  );
}

/* Recorrido guiado de bienvenida */
const PASOS = [
  ['👋', 'Bienvenido', 'Este tablero responde una pregunta: ¿cuántos delitos se esperan en Riobamba y en sus parroquias, y cómo cambiarán hasta 2029? Usa datos del ECU 911 y el catálogo del COIP.'],
  ['🚦', 'Los colores', 'Verde = normal. Amarillo = atención. Rojo = se espera más de lo habitual. Son una guía para decidir dónde mirar primero, no una certeza.'],
  ['🗺️', 'Cómo moverte', 'Empieza por las cuatro preguntas del Inicio, o abre el Mapa y toca una parroquia. Con Ctrl + K buscas cualquier cosa. Los símbolos «i» explican los términos técnicos.'],
  ['★', 'Flores y Cubijíes', 'Son las parroquias foco del proyecto. Tienen pocos delitos, así que el tablero habla en probabilidades («es poco probable…») en vez de cifras exactas.'],
];
function Tour({ cerrar }) {
  const [i, setI] = useState(0), [e, t, d] = PASOS[i];
  return (
    <div className="veil" onClick={cerrar}><div className="tour" onClick={ev => ev.stopPropagation()}>
      <div className="te">{e}</div><h2>{t}</h2><p>{d}</p>
      <div className="dots">{PASOS.map((_, k) => <i key={k} className={k === i ? 'on' : ''} />)}</div>
      <div className="row" style={{ justifyContent: 'space-between', margin: '14px 0 0' }}>
        <button className="btn sec" onClick={cerrar}>Saltar</button>
        <div className="row" style={{ margin: 0 }}>{i > 0 && <button className="btn sec" onClick={() => setI(i - 1)}>Atrás</button>}<button className="btn" onClick={() => (i < PASOS.length - 1 ? setI(i + 1) : cerrar())}>{i < PASOS.length - 1 ? 'Siguiente →' : '¡Empezar!'}</button></div>
      </div>
    </div></div>
  );
}

/* Selector de semanas: fechas claras + carita + frase simple */
function Semanas({ semanas, sem, setSem, compacto }) {
  return (
    <div className={`semanas ${compacto ? 'compacto' : ''}`}>
      {semanas.map(w => (
        <button key={w.h} className={sem === w.h ? 'on' : ''} onClick={() => setSem(w.h)} style={sem === w.h ? { borderColor: w.cara.c } : null}>
          <span className="sn">{w.etiqueta}</span>
          <b className="sf">{w.corto}</b>
          <span className="sc">{w.cara.e}</span>
          <span className="st" style={{ color: w.cara.c }}>{w.cara.t}</span>
          {!compacto && <span className="sd">Se esperan unos <b>{fmt(w.total)}</b> delitos en todo el cantón</span>}
        </button>))}
    </div>
  );
}
const Guia = ({ e, children }) => <div className="guia"><b className="e">{e}</b><div>{children}</div></div>;
const Info = ({ t }) => <span className="info" data-tip={t} tabIndex={0}>i</span>;

function Tabla({ cols, rows, onRow }) {
  return (
    <div className="tscroll"><table><thead><tr>{cols.map(c => <th key={c.t} className={c.r ? 'r' : ''} onClick={c.o} style={c.o ? { cursor: 'pointer' } : null}>{c.t}{c.o ? ' ↕' : ''}</th>)}</tr></thead>
      <tbody>{rows.map((r, i) => <tr key={i} onClick={onRow ? () => onRow(r) : undefined} style={onRow ? { cursor: 'pointer' } : null}>{cols.map(c => <td key={c.t} className={c.r ? 'r' : ''}>{c.f(r)}</td>)}</tr>)}</tbody></table></div>
  );
}
const Kpi = ({ l, v, d, c, info, n, dec, suf }) => <div className="card kpi" style={{ '--c': c }}><div className="l">{l}{info && <Info t={info} />}</div><div className="v">{n != null ? <Cuenta n={n} dec={dec} suf={suf} /> : v}</div><div className="d">{d}</div></div>;


/* Mapa de calor: cada parroquia × las 12 semanas. El color dice cuánto se aleja de lo habitual (100 = igual que el promedio del último año). */
const colorCalor = (f) => {
  const { indice: i, alerta, prediccion: pr, media_52_semanas: me } = f;
  if (alerta === 'Alta') return ['#e0533a', '#fff'];
  if (alerta === 'Media') return ['#f4b740', '#3b2a00'];
  const azar = Math.abs(pr - me) < 0.5 * Math.sqrt(Math.max(me, 0.1));   // diferencia dentro de la variación normal: no se pinta
  if (!azar && i >= 108) return ['#f9dcd5', '#6b2a1c'];
  if (!azar && i <= 92) return ['#d6e8f6', '#17476b'];
  return ['#eef2f6', '#4a5d70'];
};
function Calor({ pron, sem, setSem, orden, desde }) {
  const hs = [...new Set(pron.map(p => p.horizonte))].filter(h => h >= desde).sort((a, b) => a - b);
  const [tip, setTip] = useState(null);
  return (
    <div className="card calor">
      <h3>Las próximas semanas de un vistazo</h3>
      <p className="n">Cada cuadro es una parroquia en una semana. <b style={{ color: '#17476b' }}>Azul</b> = menos de lo habitual, <b>gris</b> = normal (o diferencia dentro de la variación normal), <b style={{ color: '#a4452f' }}>rosado</b> = algo más, <b style={{ color: '#e0533a' }}>rojo</b> = alerta. El número es el pronóstico de delitos. Toca una columna para ver esa semana.</p>
      <div className="calor-wrap">
        <table>
          <thead><tr><th />{hs.map(h => { const f = pron.find(p => p.horizonte === h); const w = semana(f.semana_inicio); return <th key={h} className={h === sem ? 'sel' : ''} onClick={() => setSem(h)}>{w.corto.split(' – ')[0]}</th>; })}</tr></thead>
          <tbody>{orden.map(n => (
            <tr key={n}><th className="rn">{nom(n)}{(n === 'CUBIJIES' || n === 'FLORES') && ' ★'}</th>
              {hs.map(h => { const f = pron.find(p => p.horizonte === h && p.parroquia_corta === n); if (!f) return <td key={h} />; const [bg, fg] = colorCalor(f);
                return <td key={h} className={h === sem ? 'sel' : ''} style={{ background: bg, color: fg }} onClick={() => setSem(h)} onMouseEnter={() => setTip({ n, h, f })} onMouseLeave={() => setTip(null)}>{fmt(f.prediccion, f.prediccion < 10 ? 1 : 0)}</td>; })}
            </tr>))}</tbody>
        </table>
      </div>
      <div className="calor-tip">{tip ? <><b>{nom(tip.n)}</b> · semana del {semana(tip.f.semana_inicio).corto}: se esperan <b>{fmt(tip.f.prediccion, 1)}</b> delitos (lo habitual es {fmt(tip.f.media_52_semanas, 1)}; índice {fmt(tip.f.indice, 0)}).</> : 'Pasa el cursor por un cuadro para ver el detalle.'}</div>
    </div>);
}

export default function Dashboard({ datos: D, pronInicial }) {
  const [sec, setSec] = useState('inicio');
  const [oscuro, setOscuro] = useState(false);
  const [par, setPar] = useState(null);              // parroquia elegida (compartida entre secciones)
  const [umbral, setUmbral] = useState(25);
  const [pron, setPron] = useState(pronInicial);
  const [mat, setMat] = useState(null);
  const [fuente, setFuente] = useState('…');
  const [paleta, setPaleta] = useState(false);
  const [tour, setTour] = useState(true);
  const [esc, setEsc] = useState('base');       // definición de delito: base (Sonia) | A | AB
  const [sem, setSem] = useState(1);            // semana elegida (horizonte 1..12 después del último dato)
  const [hoy, setHoy] = useState(null);        // fecha de hoy (solo en el navegador)
  const elegida = useRef(false);

  /* datos que vienen de la API */
  useEffect(() => { api('mapa', {}, D).then(r => { setMat(r.data); setFuente(r.fuente); }); }, [D]);
  useEffect(() => { let vivo = true; api('pronostico', { umbral, esc: esc === 'base' ? '' : esc }, D).then(r => { if (vivo) { setPron(r.data.filas); setFuente(r.fuente); } }); return () => { vivo = false; }; }, [umbral, D, esc]);
  useEffect(() => { document.documentElement.dataset.t = oscuro ? 'dark' : ''; }, [oscuro]);
  useEffect(() => { const h = location.hash.slice(1); const k = ALIAS[h] || h; if (SECC.some(s => s[0] === k)) { setSec(k); if (ALIAS[h]) setTimeout(() => document.getElementById(h)?.scrollIntoView(), 300); } }, []);
  const ir = useCallback(k => { setSec(ALIAS[k] || k); history.replaceState(null, '', '#' + k); if (ALIAS[k]) setTimeout(() => document.getElementById(k)?.scrollIntoView({ behavior: 'smooth' }), 150); else window.scrollTo(0, 0); }, []);
  const verParroquia = useCallback(n => { setPar(n); if (n) ir('mapa'); }, [ir]);
  useEffect(() => {
    const f = e => { if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); setPaleta(p => !p); } if (e.key === 'Escape') setPaleta(false); };
    window.addEventListener('keydown', f); return () => window.removeEventListener('keydown', f);
  }, []);

  useEffect(() => { setHoy(new Date()); }, []);
  /* semanas que ya pasaron no se muestran; la que contiene hoy se llama «Esta semana» */
  const semanas = useMemo(() => {
    const hs = [...new Set(pron.map(p => p.horizonte))].sort((a, b) => a - b);
    const todas = hs.map(h => {
      const filas = pron.filter(p => p.horizonte === h);
      return { h, ...semana(filas[0].semana_inicio), cara: carita(filas), total: filas.reduce((s, p) => s + p.prediccion, 0) };
    });
    if (!hoy) return todas.slice(0, 5).map((w, i) => ({ ...w, etiqueta: `Semana ${w.h}` }));
    const t = hoy.getTime();
    const vivas = todas.filter(w => w.fin.getTime() + 86400000 > t);
    const lista = (vivas.length ? vivas : todas.slice(-1)).slice(0, 5);
    return lista.map((w, i) => ({ ...w, actual: w.ini.getTime() <= t && w.fin.getTime() + 86400000 > t, etiqueta: w.ini.getTime() <= t && w.fin.getTime() + 86400000 > t ? 'Esta semana' : i === 1 ? 'La próxima' : `En ${i} semanas` }));
  }, [pron, hoy]);
  useEffect(() => { if (!elegida.current && semanas.length) setSem(semanas[0].h); }, [semanas]);
  useEffect(() => { if (semanas.length && !semanas.some(w => w.h === sem)) setSem(semanas[0].h); }, [semanas, sem]);
  const sw = semanas.find(w => w.h === sem) || semanas[0];
  const elegir = h => { elegida.current = true; setSem(h); };
  const p1 = useMemo(() => pron.filter(p => p.horizonte === sw.h), [pron, sw]);
  const total = useMemo(() => YRS.map(y => D.cambio.reduce((s, r) => s + (r[y] || 0), 0)), [D]);
  const orden = useMemo(() => ['CUBIJIES', 'FLORES', ...p1.filter(p => p.parroquia_corta !== 'CUBIJIES' && p.parroquia_corta !== 'FLORES').sort((a, b) => b.media_52_semanas - a.media_52_semanas).map(p => p.parroquia_corta)], [p1]);
  const altas = p1.filter(p => p.alerta === 'Alta');
  const rio = p1.find(p => p.parroquia_corta === 'RIOBAMBA'), cub = p1.find(p => p.parroquia_corta === 'CUBIJIES'), flo = p1.find(p => p.parroquia_corta === 'FLORES');
  const cod1 = D.codigo.find(c => c.codigo_coip === 1), res = D.resumen[0];

  return (
    <div className="app">
      <aside>
        <div className="logo"><i>S</i><div><b>STANFORD</b><small>UNACH · Ciencia de Datos e IA</small></div></div>
        <nav>{SECC.map(([k, t]) => <a key={k} className={sec === k ? 'on' : ''} onClick={() => ir(k)}><svg viewBox="0 0 24 24" fill="currentColor"><path d={ICO[k]} /></svg><span>{t}</span></a>)}</nav>
        <div className="pie">Fuente: ECU 911 (jul-2021 a sep-2026). Delitos explícitos según catálogo COIP (código 1). Los datos de Fiscalía aún no se incorporan.</div>
      </aside>

      <main>
        <header className="top">
          <div><h1>Delitos en <span>Riobamba</span>: lo que pasó y lo que viene</h1>
            <div className="sub">Predicción semanal y tendencia hasta 2029, con foco en las parroquias rurales <b>Flores</b> y <b>Cubijíes</b>.</div></div>
          <div className="row" style={{ margin: 0 }}>
            <button className="btn sec" onClick={() => setOscuro(!oscuro)}>{oscuro ? '☀️ Claro' : '🌙 Oscuro'}</button>
            <div className="chip" suppressHydrationWarning>{esc !== 'base' && <b style={{ color: 'var(--rojo)' }}>Escenario {ESC_INFO.find(x => x.k === esc)?.t} · </b>}{fuente === 'API' ? '🟢 API en vivo' : '⚪ Datos locales'} · {new Date(D.generado + 'T12:00').toLocaleDateString('es-EC', { day: 'numeric', month: 'short', year: 'numeric' })}</div>
          </div>
        </header>

        {sec === 'inicio' && (
          <section>
            <div className="grid g21">
              <div className="card hero story">
                <h3>En una frase</h3>
                <p>
                  <b>{sw.largo.charAt(0).toUpperCase() + sw.largo.slice(1)}</b> se esperan unos <b>{fmt(rio.prediccion)}</b> delitos en Riobamba. {altas.length ? <>Hay alerta alta en <b>{altas.map(a => nom(a.parroquia_corta)).join(' y ')}</b>.</> : <>No hay parroquias en alerta alta.</>} Hacia 2029 se espera un cantón <b>{total[7] < total[3] ? 'ligeramente a la baja' : 'estable o al alza'}</b>: {fmt(total[3])} delitos en 2025 → {fmt(total[7])} en 2029.
                </p>
                <p style={{ fontSize: 15, margin: '10px 0 0', color: '#cfe0ee' }}>★ En las parroquias foco: probabilidad de al menos un delito en esa semana de <b>{fmt(cub.prob_al_menos_1, 0)} %</b> en Cubijíes y <b>{fmt(flo.prob_al_menos_1, 0)} %</b> en Flores.</p>
                <div className="top3"><div className="mini" style={{ color: '#9db8cc' }}>PARROQUIAS QUE MÁS SE ALEJAN DE LO HABITUAL EN ESA SEMANA</div>
                  {p1.slice().sort((a, b) => b.indice - a.indice).slice(0, 3).map(p => <button key={p.parroquia_corta} onClick={() => verParroquia(p.parroquia_corta)}><i style={{ background: COL[p.alerta] }} /><span>{nom(p.parroquia_corta)}</span><b>{p.indice > 100 ? '▲' : '▼'} {Math.abs(p.indice - 100)} % vs lo habitual</b></button>)}</div>
                <div className="row" style={{ marginTop: 16 }}>
                  <button className="btn light" onClick={() => ir('mapa')}>🗺️ Abrir el mapa</button>
                  <button className="btn ghost" onClick={() => ir('pron')}>🚨 Ver alertas</button>
                </div>
              </div>
              <div className="card"><h3>Mapa rápido · semana {sw.corto}</h3><MiniMapa D={D} p1={p1} onSel={verParroquia} /></div>
            </div>

            <h2 className="h2">¿Qué semana quieres ver?</h2>
            <p className="n" style={{ margin: '-6px 0 12px' }}>Los datos del ECU 911 llegan hasta el domingo 27 de septiembre de 2026; desde ahí el modelo calcula hacia adelante, así que cuanto más lejana es la semana, más incierto es el pronóstico. Toca una semana y todo el tablero cambia.</p>
            <Semanas semanas={semanas} sem={sem} setSem={elegir} />
            <div className="caritas"><span>🙂 Todo tranquilo</span><span>😐 Atención</span><span>😟 Alerta</span></div>

            <h2 className="h2">Las parroquias foco del proyecto</h2>
            <div className="grid g2">
              {[cub, flo].map(p => { const [t, lv] = nivel(p.prob_al_menos_1), c = D.cambio.find(x => x.parroquia_corta === p.parroquia_corta); return (
                <button key={p.parroquia_corta} className="card foco" onClick={() => verParroquia(p.parroquia_corta)}>
                  <Medidor pct={p.prob_al_menos_1} />
                  <div style={{ flex: 1 }}>
                    <div className="row" style={{ margin: 0, justifyContent: 'space-between' }}><h3 style={{ margin: 0, fontSize: 20 }}>{nom(p.parroquia_corta)}</h3><Badge a={p.alerta} /></div>
                    <p style={{ margin: '6px 0', fontSize: 15, lineHeight: 1.5 }}>En esa semana es <b>{t}</b> que ocurra un delito.</p>
                    <p className="n" style={{ margin: 0 }}>En 2025 hubo <b>{c['2025']}</b> delitos; hacia 2029 se esperan <b>{c['2029']}</b>{ruido(c) ? ': prácticamente igual (la diferencia cabe dentro de la variación normal).' : <> ({c.cambio_2025_2029_pct > 0 ? '+' : ''}{c.cambio_2025_2029_pct} %).</>}</p>
                    <p className="n" style={{ margin: '6px 0 0', color: 'var(--azul)' }}>Ver en el mapa →</p>
                  </div>
                </button>); })}
            </div>

            <h2 className="h2">Todo el panorama</h2>
            <Calor pron={pron} sem={sw.h} setSem={elegir} orden={orden} desde={semanas[0].h} />

            <h2 className="h2">Los delitos año por año</h2>
            <div className="card"><h3>Delitos por año en el cantón</h3><p className="n">Suma de las 12 parroquias. Desde 2026 incluye pronóstico.</p>
                <LineChart h={260} x={YRS} xlab={YRS.map((y, i) => [i, y])} corte={4} series={[{ n: 'Delitos', c: '#1f6fb2', y: total.map((v, i) => (i < 4 ? v : null)) }, { n: 'Pronóstico', c: '#e0533a', dash: 1, y: total.map((v, i) => (i >= 3 ? v : null)) }]} /></div>
          </section>)}

        {sec === 'mapa' && (mat ? <MapaVivo datos={D} pron1={p1} semanas={semanas} sem={sem} setSem={elegir} mat={mat} sel={par} onSel={setPar} onTendencia={n => { setPar(n); ir('tend'); }} dark={oscuro} /> : <div className="card">Cargando mapa…</div>)}

        {sec === 'pron' && <>
          <Pronostico D={D} pron={pron} p1={p1} semanas={semanas} sem={sem} setSem={elegir} umbral={umbral} setUmbral={setUmbral} onParroquia={verParroquia} />
          <h2 className="h2" id="tend" style={{ marginTop: 28 }}>Futuro hasta 2029</h2>
          <Tendencia D={D} par={par} setPar={setPar} />
        </>}
        {sec === 'conf' && <>
          <h2 className="h2" id="modelos">¿Qué tan confiable es?</h2>
          <Modelos D={D} />
          <h2 className="h2" id="esc" style={{ marginTop: 28 }}>¿Qué cuenta como delito?</h2>
          <Escenarios D={D} esc={esc} setEsc={setEsc} ir={ir} />
          <h2 className="h2" id="abig" style={{ marginTop: 28 }}>Abigeato</h2>
          <Abigeato D={D} />
          <h2 className="h2" id="metodo" style={{ marginTop: 28 }}>Método y límites</h2>
          <Metodo />
        </>}
        <footer className="fuente">Fuente: ECU 911 (jul-2021 a sep-2026). Delitos explícitos según catálogo COIP (código 1). Los datos de Fiscalía aún no se incorporan. Proyecto STANFORD · UNACH · Ciencia de Datos e IA.</footer>
      </main>

      <nav className="bottom">{SECC.slice(0, 5).map(([k, t]) => <a key={k} className={sec === k ? 'on' : ''} onClick={() => ir(k)}><svg viewBox="0 0 24 24" fill="currentColor"><path d={ICO[k]} /></svg>{t.split(' ')[0]}</a>)}</nav>
      {tour && <Tour cerrar={() => setTour(false)} />}
      {paleta && <Paleta D={D} cerrar={() => setPaleta(false)} ir={ir} verParroquia={verParroquia} />}
    </div>
  );
}

/* ---------- Paleta de búsqueda (Ctrl+K) ---------- */
function Paleta({ D, cerrar, ir, verParroquia }) {
  const [q, setQ] = useState(''); const ref = useRef(null);
  useEffect(() => ref.current && ref.current.focus(), []);
  const items = [...SECC.map(([k, t]) => ({ t: 'Ir a: ' + t, f: () => ir(k) })), ...Object.keys(D.mensual).map(n => ({ t: 'Parroquia: ' + nom(n), f: () => verParroquia(n) }))].filter(i => i.t.toLowerCase().includes(q.toLowerCase()));
  return (
    <div className="veil" onClick={cerrar}><div className="pal" onClick={e => e.stopPropagation()}>
      <input ref={ref} value={q} onChange={e => setQ(e.target.value)} placeholder="Busca una sección o una parroquia…" onKeyDown={e => { if (e.key === 'Enter' && items[0]) { items[0].f(); cerrar(); } }} />
      {items.slice(0, 9).map(i => <button key={i.t} onClick={() => { i.f(); cerrar(); }}>{i.t}</button>)}
    </div></div>
  );
}

/* ---------- Alertas y pronóstico ---------- */
function Pronostico({ D, pron, p1, semanas, sem, setSem, umbral, setUmbral, onParroquia }) {
  const h = sem, setH = setSem;
  const [q, setQ] = useState(''), [ord, setOrd] = useState(['indice', -1]);
  const sems = [...new Set(D.pron.map(p => p.semana_inicio))].sort();
  const filas = pron.filter(p => p.horizonte === h && nom(p.parroquia_corta).toLowerCase().includes(q.toLowerCase())).sort((a, b) => ord[1] * (typeof a[ord[0]] === 'string' ? a[ord[0]].localeCompare(b[ord[0]]) : a[ord[0]] - b[ord[0]]));
  const o = k => () => setOrd(ord[0] === k ? [k, -ord[1]] : [k, -1]);
  const csv = () => { const c = 'parroquia,semana_inicio,prediccion,rango_bajo,rango_alto,prom_52_sem,prob_al_menos_1,indice,alerta\n' + filas.map(r => [r.parroquia_corta, r.semana_inicio, r.prediccion, r.rango_bajo, r.rango_alto, r.media_52_semanas, r.prob_al_menos_1, r.indice, r.alerta].join(',')).join('\n'); const a = document.createElement('a'); a.href = URL.createObjectURL(new Blob([c], { type: 'text/csv' })); a.download = 'pronostico_stanford.csv'; a.click(); };
  return (
    <section>
      <Guia e="🚦"><b>Qué estás viendo:</b> cuántos delitos se esperan en cada parroquia en la semana que elijas. <b>Rojo</b> 😟 = se espera bastante más de lo habitual, <b>amarillo</b> 😐 = atención, <b>verde</b> 🙂 = tranquilo. Toca una tarjeta para verla en el mapa.</Guia>
      <h2 className="h2" style={{ marginTop: 0 }}>Elige la semana</h2>
      <Semanas semanas={semanas} sem={sem} setSem={setSem} />
      <h2 className="h2">Parroquia por parroquia · semana {(semanas.find(w => w.h === sem) || semanas[0]).corto}</h2>
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="row" style={{ margin: 0, justifyContent: 'space-between' }}>
          <div style={{ flex: 1, minWidth: 260 }}><h3>¿Qué tan sensible quieres la alerta?<Info t="Índice = pronóstico / promedio de las últimas 52 semanas × 100. Alerta Alta si el índice supera 100 + el porcentaje elegido." /></h3>
            <p className="n" style={{ margin: 0 }}>Alerta <b>Alta</b> cuando el pronóstico supera el promedio anual en <b>{umbral} %</b> o más <b>y</b> la diferencia es mayor que la variación normal (si es de menos de un delito, se queda en Normal). El servidor recalcula todo al mover la barra.</p></div>
          <div style={{ width: 280 }}><input type="range" min="5" max="60" step="5" value={umbral} onChange={e => setUmbral(+e.target.value)} /><div className="lim"><span>Más alertas</span><span>Menos alertas</span></div></div>
        </div>
      </div>
      <div className="grid g3">
        {p1.slice().sort((a, b) => b.indice - a.indice).map(p => { const [t] = nivel(p.prob_al_menos_1); return (
          <button key={p.parroquia_corta} className="card tarj" style={p.alerta !== 'Normal' ? { borderColor: '#f3b9ac', borderWidth: 2 } : null} onClick={() => onParroquia(p.parroquia_corta)}>
            <div className="row" style={{ justifyContent: 'space-between', margin: 0 }}><h3 style={{ margin: 0, fontSize: 17 }}>{nom(p.parroquia_corta)}{p.zona_foco ? ' ★' : ''}</h3><span className={p.alerta === 'Alta' ? 'pulse' : ''}><Badge a={p.alerta} /></span></div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
              <Medidor pct={p.prob_al_menos_1} size={120} />
              <div><div className="num" style={{ fontSize: 30 }}>{fmt(p.prediccion, p.prediccion < 10 ? 1 : 0)}</div><div className="n" style={{ margin: 0 }}>delitos esperados<br />(entre {fmt(p.rango_bajo, 0)} y {fmt(p.rango_alto, 0)})</div></div>
            </div>
            <div className="n" style={{ margin: '4px 0 0' }}>{{ Normal: '🙂', Media: '😐', Alta: '😟' }[p.alerta]} En esa semana es <b>{t}</b> que ocurra al menos uno.</div>
            <div className="n" style={{ margin: '8px 0 0', display: 'flex', justifyContent: 'space-between' }}><span>Comparado con lo habitual</span><b style={{ color: p.indice > 100 ? '#e0533a' : '#3f9d6b' }}>{p.indice > 100 ? '▲' : '▼'} {Math.abs(p.indice - 100)} %</b></div>
            <div className="n" style={{ margin: '6px 0 0', color: 'var(--azul)' }}>Ver en el mapa →</div>
          </button>); })}
      </div>
      <div className="card" style={{ marginTop: 16 }}>
        <h3>Detalle de la semana elegida</h3>
        <div className="row"><select value={h} onChange={e => setH(+e.target.value)}>{semanas.map(w => <option key={w.h} value={w.h}>{w.etiqueta}: {w.corto} {w.anio}</option>)}</select>
          <input type="search" value={q} onChange={e => setQ(e.target.value)} placeholder="Buscar parroquia…" /><button className="btn sec" onClick={csv}>Descargar CSV</button></div>
        <Tabla onRow={r => onParroquia(r.parroquia_corta)} rows={filas} cols={[
          { t: 'Parroquia', o: o('parroquia_corta'), f: r => nom(r.parroquia_corta) + (r.zona_foco ? ' ★' : '') }, { t: 'Predicción', r: 1, o: o('prediccion'), f: r => fmt(r.prediccion, 1) },
          { t: 'Rango probable', r: 1, f: r => `${fmt(r.rango_bajo, 1)} – ${fmt(r.rango_alto, 1)}` }, { t: 'Prom. 52 sem.', r: 1, f: r => fmt(r.media_52_semanas, 1) },
          { t: 'Prob. ≥ 1', r: 1, o: o('prob_al_menos_1'), f: r => r.prob_al_menos_1 + ' %' }, { t: 'Índice', r: 1, o: o('indice'), f: r => r.indice }, { t: 'Alerta', f: r => <Badge a={r.alerta} /> }]} />
      </div>
    </section>
  );
}

/* ---------- Tendencia a 2029 ---------- */
function Tendencia({ D, par, setPar }) {
  const pars = Object.keys(D.mensual).sort((a, b) => FOCO.includes(b) - FOCO.includes(a) || a.localeCompare(b));
  const p = par || 'CUBIJIES';
  const [patron, setPatron] = useState(false);
  const [modo, setModo] = useState('mes'), [comp, setComp] = useState(['RIOBAMBA', 'CALPI', 'LICAN']), [T, setT] = useState(null);
  const meses = D.mensual.RIOBAMBA.mes;
  useEffect(() => { let v = true; api('tendencia', { parroquia: p }, D).then(r => v && setT(r.data)); return () => { v = false; }; }, [p, D]);
  const lab = meses.map((s, i) => (s.endsWith('-01') ? [i, s.slice(0, 4)] : null)).filter(Boolean);
  const roll = a => a.map((_, i) => (i < 11 ? null : a.slice(i - 11, i + 1).reduce((x, y) => x + (y || 0), 0)));
  const fil = D.cambio.find(c => c.parroquia_corta === p);
  let grafico = null;
  if (T && modo !== 'comp') {
    const m = T.serie, ic = m.tipo.indexOf('Pronóstico'), x = m.mes.map(mesTxt);
    grafico = modo === 'mes'
      ? <LineChart h={340} x={x} xlab={lab} corte={ic} yfmt={v => fmt(v, v < 10 ? 1 : 0)}
          series={[{ n: 'Real', c: '#1f6fb2', y: m.inc.map((v, i) => (m.tipo[i] === 'Real' ? v : null)) }, { n: 'Pronóstico', c: '#e0533a', dash: 1, y: m.inc.map((v, i) => (i >= ic - 1 ? v : null)) },
            ...(patron ? [{ n: 'Patrón histórico por mes (referencia)', c: '#7a5af8', dash: 1, y: m.mes.map((ms, i) => { if (i < ic - 1) return null; const mm = ms.slice(5), r = m.mes.map((q, j) => (q.slice(5) === mm && m.tipo[j] === 'Real' ? m.inc[j] : null)).filter(v => v != null); return r.length ? r.reduce((a, b) => a + b, 0) / r.length : null; }) }] : [])]}
          bands={[{ lo: m.b95, hi: m.a95, c: '#e0533a', o: 0.1 }, { lo: m.b80, hi: m.a80, c: '#e0533a', o: 0.18 }]} />
      : <LineChart h={340} x={x} xlab={lab} corte={ic} series={[{ n: 'Real (12 meses)', c: '#1f6fb2', y: T.acum12.map((v, i) => (m.tipo[i] === 'Real' ? v : null)) }, { n: 'Pronóstico (12 meses)', c: '#e0533a', dash: 1, y: T.acum12.map((v, i) => (i >= ic - 1 ? v : null)) }]} />;
  }
  if (modo === 'comp') {
    const b = meses.indexOf('2025-12');
    /* banda al 80 %: el error de los meses pronosticados dentro de cada ventana de 12 meses se combina como independiente (raíz de la suma de cuadrados) */
    const banda = q => { const M = D.mensual[q], r = roll(M.inc), esc = b => (r[b] || 1);
      const w = M.inc.map((_, i) => (i < 11 ? null : Math.sqrt(M.inc.slice(i - 11, i + 1).reduce((t, v, k) => { const j = i - 11 + k; return t + (M.tipo[j] === 'Pronóstico' && M.a80[j] != null ? (M.a80[j] - v) ** 2 : 0); }, 0))));
      return { lo: r.map((v, i) => (v == null ? null : Math.max(0, v - w[i]) / esc(b) * 100)), hi: r.map((v, i) => (v == null ? null : (v + w[i]) / esc(b) * 100)) }; };
    grafico = <LineChart h={340} x={meses.map(mesTxt)} xlab={lab} corte={meses.indexOf('2026-10')}
      bands={comp.map(q => ({ ...banda(q), c: PAL[pars.indexOf(q)], o: 0.13 }))}
      series={comp.map(q => { const r = roll(D.mensual[q].inc); return { n: nom(q), c: PAL[pars.indexOf(q)], y: r.map(v => (v == null ? null : (v / (r[b] || 1)) * 100)) }; })} />;
  }
  return (
    <section>
      <Guia e="🔮"><b>Qué estás viendo:</b> cómo han sido y cómo serían los delitos de cada parroquia hasta 2029. Elige una parroquia, o usa <b>Comparar</b> para ver varias juntas. La zona sombreada es el rango donde probablemente caerá la cifra.</Guia>
      <div className="card">
        <div className="row"><h3 style={{ margin: 0 }}>Tendencia mensual hasta 2029</h3>
          <select value={p} onChange={e => setPar(e.target.value)}>{pars.map(q => <option key={q} value={q}>{nom(q)}{FOCO.includes(q) ? ' ★' : ''}</option>)}</select>
          <div className="seg">{[['mes', 'Mensual'], ['acum', 'Últimos 12 meses'], ['comp', 'Comparar']].map(([k, t]) => <button key={k} className={modo === k ? 'on' : ''} onClick={() => setModo(k)}>{t}</button>)}</div>
          {T && modo === 'mes' && <label className="chip" style={{ cursor: 'pointer' }}><input type="checkbox" checked={patron} onChange={e => setPatron(e.target.checked)} /> Ver patrón por mes (referencia)</label>}
          {T && modo !== 'comp' && <span className="chip">Método ganador: <b>{T.serie.modelo}</b></span>}</div>
        {modo === 'comp' && <div className="pills">{pars.map(q => { const on = comp.includes(q); return <span key={q} className={`pill ${on ? 'on' : ''}`} style={on ? { background: PAL[pars.indexOf(q)], borderColor: PAL[pars.indexOf(q)] } : null} onClick={() => setComp(on ? comp.filter(z => z !== q) : [...comp, q])}>{nom(q)}</span>; })}</div>}
        <p className="n" style={{ marginTop: 10 }}>{modo === 'mes' ? 'Línea sólida = datos reales; punteada = pronóstico; bandas = rango probable al 80 % y 95 %. Con pocos casos las bandas son amplias: es lo honesto.' : modo === 'acum' ? 'Suma móvil de 12 meses: quita la estacionalidad y muestra la tendencia.' : 'Índice: 100 = delitos de los 12 meses que terminan en dic-2025. Permite comparar parroquias grandes y pequeñas.'}</p>
        {grafico || <p className="n">Cargando…</p>}
        {modo === 'mes' && T && !/mes del año/i.test(T.serie.modelo) && (() => {
          const z = D.backtest.filter(b => b.zona === (par === 'RIOBAMBA' ? 'Urbana' : 'Rurales')), g = z.find(b => b.modelo === T.serie.modelo), e = z.find(b => /mes del año/i.test(b.modelo));
          return <div className="aviso" style={{ marginTop: 12 }}>💡 <b>¿Por qué el pronóstico sale recto y antes tenía curvas?</b> Las curvas venían de un modelo que repite el patrón de cada mes. En las parroquias con pocos delitos ese patrón es casi pura variación impredecible (un mes con 4 casos no significa que se repita). Lo probamos con los últimos 24 meses: {g && e ? <>el modelo recto se equivocó <b>{fmt(g.MAE_mensual, 2)}</b> delitos por mes y el de curvas <b>{fmt(e.MAE_mensual, 2)}</b>, así que el recto acierta más.</> : 'el modelo recto acertó más.'} Por eso se usa la línea recta: es el nivel normal esperado. Si quieres ver cómo sería con curvas, activa «Ver patrón por mes (referencia)» (línea morada), sabiendo que acierta menos. La zona sombreada muestra que cualquier mes puede salir más alto o más bajo.</div>;
        })()}
        {modo !== 'mes' && <div className="aviso" style={{ marginTop: 12 }}>💡 <b>¿Por qué después de 2027 se ve casi recta?</b> Lejos en el tiempo el modelo solo puede proyectar el nivel normal de cada mes y una tendencia suave; los picos y valles del pasado no se pueden adivinar. Además, al sumar 12 meses se cancelan las diferencias entre meses. Recta no significa «no cambiará»: significa «no hay señal clara». Las sombras muestran cómo crece la incertidumbre.</div>}
        {T && modo !== 'comp' && (() => {
          const m = T.serie, por = Array(12).fill(0), cnt = Array(12).fill(0);
          m.mes.forEach((s, i) => { if (m.tipo[i] === 'Real') { por[+s.slice(5) - 1] += m.inc[i] || 0; cnt[+s.slice(5) - 1] += 1; } });
          const prom = por.map((v, i) => v / (cnt[i] || 1)), top = prom.map((v, i) => [v, i]).sort((a, b) => b[0] - a[0]).slice(0, 2).map(x => ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'][x[1]]);
          return <div className="resumen">💬 <span>En <b>{nom(p)}</b> los delitos pasarían de <b>{fil['2025']}</b> en 2025 a <b>{fil['2029']}</b> en 2029 {ruido(fil) ? <>(se mantendría <b>estable</b>: la diferencia cabe dentro de la variación normal)</> : <>({fil.cambio_2025_2029_pct > 0 ? 'sube' : 'baja'} {Math.abs(fil.cambio_2025_2029_pct)} %)</>}. {prom.some(v => v > 0) ? <>Históricamente los meses con más casos son <b>{top[0]}</b> y <b>{top[1]}</b>.</> : null}</span></div>;
        })()}
      </div>
      <div className="grid g2" style={{ marginTop: 16 }}>
        <div className="card"><h3>Delitos por año · {nom(p)}</h3>
          <Tabla cols={[{ t: 'Año', f: r => r.a }, { t: 'Delitos', r: 1, f: r => fmt(r.v) }, { t: 'Tipo', f: r => r.t }]} rows={YRS.map(y => ({ a: y, v: fil[y], t: +y <= 2025 ? 'Real' : +y === 2026 ? 'Real + pronóstico' : 'Pronóstico' }))} /></div>
        <div className="card"><h3>Cambio 2025 → 2029</h3><p className="n">Solo parroquias con 5 o más delitos en 2025. Las barras <b>grises</b> son cambios que caben dentro de la variación normal (±2√n): no son una subida ni una bajada real.</p>
          <Barras fmtv={v => fmt(v, 1) + ' %'} items={D.cambio.filter(c => c['2025'] >= 5).sort((a, b) => a.cambio_2025_2029_pct - b.cambio_2025_2029_pct).map(c => ({ n: `${nom(c.parroquia_corta)} (${c['2025']}→${c['2029']})`, v: Math.abs(c.cambio_2025_2029_pct), c: ruido(c) ? '#b8c4d1' : c.cambio_2025_2029_pct > 0 ? '#e0533a' : '#2f86b8' }))} />
          <div className="leg"><span><i style={{ background: '#2f86b8' }} />Baja</span><span><i style={{ background: '#e0533a' }} />Sube</span><span><i style={{ background: '#b8c4d1' }} />Variación normal</span></div></div>
      </div>
    </section>
  );
}

/* ---------- Modelos ---------- */
function Modelos({ D }) {
  const m = D.resumen[0], b = D.resumen.find(r => r.modelo === 'Base: semana anterior');
  return (
    <section>
      <div className="aviso" style={{ marginBottom: 16 }}>Pregunta clave: <b>¿se puede confiar en el pronóstico?</b> Se reservó el último año (52 semanas) como prueba y se comparó lo predicho con lo que realmente pasó.</div>
      <div className="card" style={{ marginBottom: 16 }}>
        <h3>¿Puedo confiar en el pronóstico de cada parroquia?</h3>
        <p className="n">Hay un error que ningún modelo puede evitar: los delitos no son «al azar», pero dependen de decisiones y circunstancias que no quedan en los datos, y eso hace que un delito más o menos en una semana no se pueda anticipar (la <b>variación natural</b>). Aquí se compara cuánto se equivocó nuestro modelo en el último año con ese <b>mínimo posible</b>. Si se parecen, el modelo ya acierta lo máximo que los datos permiten; <b>un error relativo alto en una parroquia pequeña no significa que el modelo esté mal</b>, sino que casi no hay casos que predecir.</p>
        <div className="grid g3">{D.azar.map(r => { const k = r.MAE_modelo / Math.max(r.MAE_modelo_perfecto, 0.001), [t, c, ic] = k <= 1.15 ? ['Acierta lo máximo posible', '#3f9d6b', '🟢'] : k <= 1.35 ? ['Muy cerca del máximo', '#d08a00', '🟡'] : ['Aún hay margen', '#e0533a', '🟠'];
          return (
          <div className="conf" key={r.parroquia_corta} style={{ borderLeftColor: c }}><b>{nom(r.parroquia_corta)}</b><span style={{ color: c }}>{ic} {t}</span>
            <i>se equivoca ≈ {fmt(r.MAE_modelo, 2)} delitos por semana · mínimo posible ≈ {fmt(r.MAE_modelo_perfecto, 2)}</i>
            {r.media_semanal < 1 && <i style={{ display: 'block', marginTop: 2 }}>Pocos delitos ({fmt(r.media_semanal, 2)} por semana): usa la probabilidad, no el número exacto.</i>}</div>); })}</div>
      </div>
      <div className="grid g4">
        <Kpi l="Error del modelo elegido" v={fmt(m['Todas las parroquias'], 2)} d="delitos por parroquia y semana (MAE)" c="var(--verde)" info="MAE = error absoluto medio. Menor es mejor." />
        <Kpi l="Mejora vs «igual que la semana pasada»" v={fmt((1 - m['Todas las parroquias'] / b['Todas las parroquias']) * 100, 0) + ' %'} d={`${fmt(b['Todas las parroquias'], 2)} → ${fmt(m['Todas las parroquias'], 2)}`} c="var(--azul)" />
        <Kpi l="Riobamba (urbana)" v={fmt(m['Urbana (Riobamba)'], 1)} d="error ≈ 12 % del nivel semanal" c="var(--cian)" />
        <Kpi l="Cubijíes / Flores" v={`${fmt(m['Cubijíes'], 2)} / ${fmt(m['Flores'], 2)}`} d="delitos por semana" c="var(--ambar)" />
      </div>
      <div className="grid g2" style={{ marginTop: 16 }}>
        <div className="card"><h3>Error de cada modelo</h3><p className="n">Menor es mejor. Verde = elegido; gris = comparaciones simples.</p>
          <Barras max={2} fmtv={v => fmt(v, 2)} items={D.resumen.map((r, i) => ({ n: r.modelo.replace('Combinación', 'Comb.'), v: r['Todas las parroquias'], c: i === 0 ? '#3f9d6b' : r.modelo.startsWith('Base') ? '#c5d0da' : '#4c93c9' }))} /></div>
        <div className="card"><h3>Predicho vs real (52 semanas de prueba)</h3>
          <Tabla cols={[{ t: 'Parroquia', f: r => nom(r.parroquia_corta) }, { t: 'Real', r: 1, f: r => fmt(r.real_total) }, { t: 'Predicho', r: 1, f: r => fmt(r.predicho_total) }, { t: 'MAE', r: 1, f: r => fmt(r.MAE, 2) }]} rows={D.rv} /></div>
      </div>
      <div className="card" style={{ marginTop: 16 }}><h3>Mínimo de error posible<Info t="Ningún modelo acierta todo: los delitos dependen de decisiones y circunstancias que no quedan registradas en los datos, así que siempre queda una parte que no se puede anticipar." /></h3>
        <p className="n">«Error relativo» compara el error del modelo con el nivel semanal medio. En parroquias con casi cero delitos es alto por naturaleza.</p>
        <Tabla cols={[{ t: 'Parroquia', f: r => nom(r.parroquia_corta) }, { t: 'Media semanal', r: 1, f: r => fmt(r.media_semanal, 2) }, { t: 'MAE modelo perfecto', r: 1, f: r => fmt(r.MAE_modelo_perfecto, 2) }, { t: 'MAE modelo', r: 1, f: r => fmt(r.MAE_modelo, 2) }, { t: 'Error relativo', r: 1, f: r => fmt(r.error_relativo_pct, 0) + ' %' }]} rows={D.azar} /></div>
    </section>
  );
}

/* ---------- Abigeato ---------- */
function Abigeato({ D }) {
  const ab = D.abigeato, tot = ab['Por anio'].reduce((s, r) => s + r.casos, 0), rur = ab['Por parroquia'].filter(r => r.parroquia_corta !== 'RIOBAMBA').reduce((s, r) => s + r.casos, 0);
  return (
    <section>
      <Guia e="🐄"><b>Qué estás viendo:</b> el robo de ganado (abigeato) en el cantón: cuántos casos hubo cada año, en qué meses y días ocurre más y en qué parroquias.</Guia>
      <div className="grid g3">
        <Kpi l="Casos registrados" v={fmt(tot)} d="jul-2021 a sep-2026" c="var(--azul)" />
        <Kpi l="En zonas rurales" v={fmt((rur / tot) * 100, 0) + ' %'} d="fuera de la zona urbana de Riobamba" c="var(--verde)" />
        <Kpi l="Año más alto" v={ab['Por anio'].reduce((a, b) => (b.casos > a.casos ? b : a)).anio} d="2021 y 2026 son años incompletos" c="var(--ambar)" />
      </div>
      <div className="grid g2" style={{ marginTop: 16 }}>
        <div className="card"><h3>Abigeato por año</h3><Columnas yfmt={v => fmt(v)} items={ab['Por anio'].map(r => ({ n: r.anio, v: r.casos }))} /></div>
        <div className="card"><h3>Promedio por mes del año</h3><p className="n">Más casos en mayo y de agosto a octubre. Febrero queda algo bajo porque febrero de 2023 no trae el tipo de delito.</p><Columnas color="#2bb3c0" items={ab['Por mes'].map(r => ({ n: r.mes, l: r.mes.slice(0, 3), v: r.promedio }))} /></div>
        <div className="card"><h3>Dónde ocurre</h3><Barras color="#3f9d6b" items={ab['Por parroquia'].map(r => ({ n: nom(r.parroquia_corta), v: r.casos }))} /></div>
        <div className="card"><h3>Qué día de la semana</h3><Columnas color="#7d5bbe" yfmt={v => fmt(v)} items={ab['Por dia'].map(r => ({ n: r.dia_semana, l: r.dia_semana.slice(0, 3), v: r.casos }))} /></div>
      </div>
    </section>
  );
}

/* ---------- ¿Qué cuenta como delito? (escenarios) ---------- */
const ESC_INFO = [
  { k: 'base', fila: 'Base (Sonia)', t: 'Base de Sonia', e: '📘', d: 'Solo lo que el catálogo COIP de Sonia Calle marca como delito explícito (código 1). Es el resultado oficial del proyecto.' },
  { k: 'A', fila: 'A', t: 'Ampliado A', e: '📗', d: 'Suma 15 tipos que el COIP nombra expresamente (violencia física familiar, drogas, armas de fuego, abandono, delitos sexuales…). Confianza alta.' },
  { k: 'AB', fila: 'A+B', t: 'Ampliado A+B', e: '📙', d: 'Suma además 15 tipos probables (agresiones, personas heridas, daños, fraude). Confianza media o baja: depende de lo que realmente pasó.' },
  { k: 'ED', fila: 'ED', t: 'Reglas del equipo', e: '📕', d: 'Todo lo que las reglas de palabras clave del equipo llaman «delito» (el método anterior al catálogo de Sonia). Es una segunda opinión independiente; la categoría la calculamos nosotros, no viene del ECU 911.' },
];
function Escenarios({ D, esc, setEsc, ir }) {
  const E = D.esc;
  const [nivel, setNivel] = useState('todos'), [q, setQ] = useState('');
  if (!E) return <section><div className="card">Sin datos de escenarios.</div></section>;
  const fila = n => E.comparacion.find(r => r.escenario === n) || {};
  const claves = Object.keys(E.comparacion[0] || {}).filter(k => k !== 'escenario');
  const filas = claves.map(k => ({ k, ...Object.fromEntries(E.comparacion.map(r => [r.escenario, r[k]])) }));
  const terms = E.terminos.filter(t => (nivel === 'todos' || t.nivel.startsWith(nivel)) && (t.subtipo + t.justificacion).toLowerCase().includes(q.toLowerCase())).sort((a, b) => a.nivel[0].localeCompare(b.nivel[0]) || b.registros - a.registros);
  const colN = { A: '#3f9d6b', B: '#d08a00', C: '#8a98a8' };
  return (
    <section>
      <Guia e="📚"><b>¿Qué cuenta como «delito»?</b> El ECU 911 registra llamadas de todo tipo (patrullajes, escándalos, heridos…). El proyecto parte del catálogo de Sonia Calle y el equipo propone <b>sumar</b> otros tipos que el COIP sí nombra. Elige una definición: <b>todo el tablero se recalcula</b> con ella.</Guia>
      <div className="aviso" style={{ margin: '14px 0' }}>Las propuestas del equipo son un <b>borrador</b>: Sonia, los tutores o la Fiscalía deben validarlas antes de usarse como resultado final.</div>
      <div className="semanas" style={{ gridTemplateColumns: 'repeat(auto-fit,minmax(240px,1fr))' }}>
        {ESC_INFO.map(x => { const f = fila(x.fila); return (
          <button key={x.k} className={esc === x.k ? 'on' : ''} onClick={() => setEsc(x.k)}>
            <span className="sc">{x.e}</span><b className="sf">{x.t}</b>
            <span className="sd" style={{ marginTop: 0 }}>{x.d}</span>
            <span className="sd"><b>{fmt(f['Delitos (registros)'])}</b> delitos · error en Riobamba <b>{f['Error relativo Riobamba %']} %</b></span>
            <span className="st" style={{ color: esc === x.k ? '#1f6fb2' : 'var(--mut)' }}>{esc === x.k ? '✔ En uso en todo el tablero' : 'Tocar para usar'}</span>
          </button>); })}
      </div>
      <div className="grid g2" style={{ marginTop: 16 }}>
        <div className="card"><h3>Comparación lado a lado</h3>
          <Tabla cols={[{ t: 'Indicador', f: r => r.k }, ...ESC_INFO.map(x => ({ t: x.t, r: 1, f: r => r[x.fila] }))]} rows={filas} /></div>
        <div className="card"><h3>Qué nos dice</h3>
          <ul className="lista">
            <li><b>Riobamba mejora un poco</b> al ampliar: el error relativo baja de {fila('Base (Sonia)')['Error relativo Riobamba %']} % a {fila('A+B')['Error relativo Riobamba %']} %.</li>
            <li><b>Flores y Cubijíes no mejoran</b>: tienen muy pocos casos por semana, y sumar tipos no ayuda.</li>
            <li><b>Casi no hay alertas</b>: solo se marca una parroquia cuando el pronóstico supera al promedio por más de lo que explica la variación normal. En 12 semanas, con la base de Sonia hay {fila('Base (Sonia)')['Alertas (altas o medias, 12 semanas)']} alertas; con A, {fila('A')['Alertas (altas o medias, 12 semanas)']}; con A+B, {fila('A+B')['Alertas (altas o medias, 12 semanas)']}. Es decir, el modelo no espera nada fuera de lo normal.</li>
          </ul>
          <button className="btn sec" onClick={() => ir('pron')}>Ver alertas con esta definición →</button></div>
      </div>
      <h2 className="h2">Tipos de llamada que se proponen · {terms.length} de {E.terminos.length}</h2>
      <div className="card">
        <div className="row"><input placeholder="Buscar un tipo (ej. armas, violencia)…" value={q} onChange={e => setQ(e.target.value)} />
          <select value={nivel} onChange={e => setNivel(e.target.value)}><option value="todos">Todos</option><option value="A">A · Incluir (alta)</option><option value="B">B · Solo ampliado (media/baja)</option><option value="C">C · Mantener fuera</option></select></div>
        <Tabla cols={[{ t: 'Tipo (ECU 911)', f: r => r.subtipo }, { t: 'Casos', r: 1, f: r => fmt(r.registros) }, { t: 'Sonia', r: 1, f: r => r.sonia },
          { t: 'Propuesta', f: r => <b style={{ color: colN[r.nivel[0]] }}>{r.nivel.split(' · ')[1] ? r.nivel.split(' (')[0] : r.nivel}</b> }, { t: 'COIP', f: r => r.articulo || '—' }, { t: 'Por qué', f: r => r.justificacion }]} rows={terms.slice(0, 60)} />
        {terms.length > 60 && <p className="n">Se muestran 60; usa el buscador o el filtro para ver el resto.</p>}
      </div>
    </section>
  );
}

function Metodo() {
  return (
    <section><div className="grid g2">
      <div className="card hero"><h3>De dónde sale cada número</h3><p className="n">Todo se calcula con scripts de R reproducibles (01 a 13) en el repositorio del proyecto.</p>
        <ol className="lista"><li>Se unifican los archivos del ECU 911 y se limpian (fechas, duplicados, parroquias).</li><li>Se filtra Riobamba y se clasifica cada registro con el catálogo COIP.</li><li>Se predice solo el código 1 (delito explícito) por parroquia y semana.</li><li>Zona urbana: random forest. Parroquias rurales: binomial negativa.</li><li>La tendencia a 2029 usa el método que mejor acertó en un backtest de 24 meses.</li></ol></div>
      <div className="card"><h3>Límites que debes conocer</h3>
        <ul className="lista"><li>El ECU 911 registra llamadas, no sentencias: lesiones, tránsito y drogas dependen de datos que solo tiene la Fiscalía.</li><li>La ubicación llega solo a nivel de parroquia; no hay coordenadas de cada incidente.</li><li>Flores y Cubijíes tienen pocos casos (91 % y 64 % de sus semanas sin ninguno): se pronostica una probabilidad, no un número exacto.</li><li>Febrero de 2023 no trae subtipo y se estimó con los meses vecinos.</li><li>La base de la Fiscalía se incorporará para validar el modelo.</li></ul>
        <p className="n" style={{ marginTop: 12 }}>Proyecto STANFORD · UNACH · tutores Mg. Ronny Pomboza y Mg. Johanna Moyano.</p></div>
    </div></section>
  );
}
