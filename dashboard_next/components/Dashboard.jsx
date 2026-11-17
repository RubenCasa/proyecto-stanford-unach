'use client';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import dynamic from 'next/dynamic';
import { Barras, Columnas, LineChart } from './Charts';
import { api } from '../lib/api';
import { COL, FOCO, PAL, fmt, mesTxt, nom } from '../lib/util';

const MapaVivo = dynamic(() => import('./MapaVivo'), { ssr: false, loading: () => <div className="card" style={{ height: 500, display: 'grid', placeItems: 'center' }}>Cargando mapa…</div> });

const ICO = { inicio: 'M3 13h8V3H3zm0 8h8v-6H3zm10 0h8V11h-8zm0-18v6h8V3z', mapa: 'M20.5 3l-6 2-5-2-6 2v16l6-2 5 2 6-2zM9 5.5l5 1.7v11.3l-5-1.7z', pron: 'M12 2l3 7h7l-5.5 4.5L18 21l-6-4-6 4 1.5-7.5L2 9h7z', tend: 'M3 17l6-6 4 4 8-8v6h2V3h-10v2h6l-6 6-4-4-8 8z', modelos: 'M12 3l9 4.5v9L12 21l-9-4.5v-9zm0 2.2L5.5 8.4 12 11.6l6.5-3.2z', abig: 'M4 20h16v-2H4zM6 8l3-4 3 4 3-4 3 4v8H6z', metodo: 'M12 2a10 10 0 100 20 10 10 0 000-20zm1 15h-2v-6h2zm0-8h-2V7h2z' };
const SECC = [['inicio', 'Inicio'], ['mapa', 'Mapa'], ['pron', 'Alertas y pronóstico'], ['tend', 'Futuro hasta 2029'], ['modelos', '¿Qué tan confiable?'], ['abig', 'Abigeato'], ['metodo', 'Método y límites']];
const YRS = ['2022', '2023', '2024', '2025', '2026', '2027', '2028', '2029'];
const Badge = ({ a }) => <span className={`badge b-${a}`}>{a}</span>;
const Info = ({ t }) => <span className="info" data-tip={t} tabIndex={0}>i</span>;

function Tabla({ cols, rows, onRow }) {
  return (
    <div className="tscroll"><table><thead><tr>{cols.map(c => <th key={c.t} className={c.r ? 'r' : ''} onClick={c.o} style={c.o ? { cursor: 'pointer' } : null}>{c.t}{c.o ? ' ↕' : ''}</th>)}</tr></thead>
      <tbody>{rows.map((r, i) => <tr key={i} onClick={onRow ? () => onRow(r) : undefined} style={onRow ? { cursor: 'pointer' } : null}>{cols.map(c => <td key={c.t} className={c.r ? 'r' : ''}>{c.f(r)}</td>)}</tr>)}</tbody></table></div>
  );
}
const Kpi = ({ l, v, d, c, info }) => <div className="card kpi" style={{ '--c': c }}><div className="l">{l}{info && <Info t={info} />}</div><div className="v">{v}</div><div className="d">{d}</div></div>;

export default function Dashboard({ datos: D, pronInicial }) {
  const [sec, setSec] = useState('inicio');
  const [oscuro, setOscuro] = useState(false);
  const [par, setPar] = useState(null);              // parroquia elegida (compartida entre secciones)
  const [umbral, setUmbral] = useState(25);
  const [pron, setPron] = useState(pronInicial);
  const [mat, setMat] = useState(null);
  const [fuente, setFuente] = useState('…');
  const [paleta, setPaleta] = useState(false);

  /* datos que vienen de la API */
  useEffect(() => { api('mapa', {}, D).then(r => { setMat(r.data); setFuente(r.fuente); }); }, [D]);
  useEffect(() => { let vivo = true; api('pronostico', { umbral }, D).then(r => { if (vivo) { setPron(r.data.filas); setFuente(r.fuente); } }); return () => { vivo = false; }; }, [umbral, D]);
  useEffect(() => { document.documentElement.dataset.t = oscuro ? 'dark' : ''; }, [oscuro]);
  useEffect(() => { const h = location.hash.slice(1); if (SECC.some(s => s[0] === h)) setSec(h); }, []);
  const ir = useCallback(k => { setSec(k); history.replaceState(null, '', '#' + k); window.scrollTo(0, 0); }, []);
  const verParroquia = useCallback(n => { setPar(n); if (n) ir('mapa'); }, [ir]);
  useEffect(() => {
    const f = e => { if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); setPaleta(p => !p); } if (e.key === 'Escape') setPaleta(false); };
    window.addEventListener('keydown', f); return () => window.removeEventListener('keydown', f);
  }, []);

  const p1 = useMemo(() => pron.filter(p => p.horizonte === 1), [pron]);
  const total = useMemo(() => YRS.map(y => D.cambio.reduce((s, r) => s + (r[y] || 0), 0)), [D]);
  const altas = p1.filter(p => p.alerta === 'Alta');
  const rio = p1.find(p => p.parroquia_corta === 'RIOBAMBA'), cub = p1.find(p => p.parroquia_corta === 'CUBIJIES'), flo = p1.find(p => p.parroquia_corta === 'FLORES');
  const cod1 = D.codigo.find(c => c.codigo_coip === 1), res = D.resumen[0];

  return (
    <div className="app">
      <aside>
        <div className="logo"><i>S</i><div><b>STANFORD</b><small>UNACH · Ciencia de Datos e IA</small></div></div>
        <nav>{SECC.map(([k, t]) => <a key={k} className={sec === k ? 'on' : ''} onClick={() => ir(k)}><svg viewBox="0 0 24 24" fill="currentColor"><path d={ICO[k]} /></svg><span>{t}</span></a>)}</nav>
        <button className="busca" onClick={() => setPaleta(true)}>🔎 Buscar… <kbd>Ctrl K</kbd></button>
        <div className="pie">Fuente: ECU 911 (jul-2021 a sep-2026). Delitos explícitos según catálogo COIP (código 1). Los datos de Fiscalía aún no se incorporan.</div>
      </aside>

      <main>
        <header className="top">
          <div><h1>Delitos en <span>Riobamba</span>: lo que pasó y lo que viene</h1>
            <div className="sub">Predicción semanal y tendencia hasta 2029, con foco en las parroquias rurales <b>Flores</b> y <b>Cubijíes</b>.</div></div>
          <div className="row" style={{ margin: 0 }}>
            <button className="btn sec" onClick={() => setOscuro(!oscuro)}>{oscuro ? '☀️ Claro' : '🌙 Oscuro'}</button>
            <div className="chip" suppressHydrationWarning>{fuente === 'API' ? '🟢 API en vivo' : '⚪ Datos locales'} · {new Date(D.generado + 'T12:00').toLocaleDateString('es-EC', { day: 'numeric', month: 'short', year: 'numeric' })}</div>
          </div>
        </header>

        {sec === 'inicio' && (
          <section>
            <div className="card hero story">
              <h3>En una frase</h3>
              <p>
                La próxima semana se esperan unos <b>{fmt(rio.prediccion)}</b> delitos en Riobamba. {altas.length ? <>Hay alerta alta en <b>{altas.map(a => nom(a.parroquia_corta)).join(' y ')}</b>.</> : <>No hay parroquias en alerta alta.</>} En las parroquias foco, la probabilidad de que ocurra al menos un delito es de <b>{cub.prob_al_menos_1} %</b> en Cubijíes y <b>{flo.prob_al_menos_1} %</b> en Flores. Hacia 2029 se espera un cantón <b>{total[7] < total[3] ? 'ligeramente a la baja' : 'estable o al alza'}</b> ({fmt(total[3])} delitos en 2025 → {fmt(total[7])} en 2029).
              </p>
            </div>
            <h2 className="h2">¿Qué quieres saber?</h2>
            <div className="grid g4">
              {[['🗺️', '¿Dónde hay más riesgo?', 'Mapa real con alertas por parroquia', 'mapa'], ['🚨', '¿Qué pasa esta semana?', 'Alertas y delitos esperados', 'pron'], ['🔮', '¿Cómo será 2029?', 'Tendencia con rangos de confianza', 'tend'], ['✅', '¿Qué tan confiable es?', 'Errores y límites del modelo', 'modelos']].map(([e, t, d, k]) => (
                <button key={k} className="card tile" onClick={() => ir(k)}><span className="emo">{e}</span><b>{t}</b><span>{d}</span></button>))}
            </div>
            <div className="grid g4" style={{ marginTop: 16 }}>
              <Kpi l="Delitos explícitos (COIP)" v={fmt(cod1.registros)} d={`${cod1.pct} % de los registros`} c="var(--azul)" info="Delitos claros según el catálogo COIP de Sonia Calle (código 1). Es lo que predice el modelo." />
              <Kpi l="Delitos 2025 en el cantón" v={fmt(total[3])} d={`2029: ${fmt(total[7])} (${fmt((total[7] / total[3] - 1) * 100, 1)} %)`} c="var(--cian)" />
              <Kpi l="Alertas altas esta semana" v={altas.length} d={altas.length ? altas.map(a => nom(a.parroquia_corta)).join(', ') : 'ninguna'} c="var(--rojo)" info="Alta = el pronóstico supera el promedio de las últimas 52 semanas en el porcentaje que elijas en «Alertas y pronóstico»." />
              <Kpi l="Error del modelo" v={fmt(res['Todas las parroquias'], 2)} d="delitos por semana y parroquia" c="var(--verde)" info="MAE: cuántos delitos se equivoca el modelo, en promedio, por parroquia y semana." />
            </div>
            <div className="grid g21" style={{ marginTop: 16 }}>
              <div className="card"><h3>Delitos por año en el cantón</h3><p className="n">Suma de las 12 parroquias. Desde 2026 incluye pronóstico.</p>
                <LineChart h={260} x={YRS} xlab={YRS.map((y, i) => [i, y])} corte={4} series={[{ n: 'Delitos', c: '#1f6fb2', y: total.map((v, i) => (i < 4 ? v : null)) }, { n: 'Pronóstico', c: '#e0533a', dash: 1, y: total.map((v, i) => (i >= 3 ? v : null)) }]} /></div>
              <div className="card"><h3>¿Qué es un delito aquí?</h3><p className="n">Clasificación COIP de Sonia Calle sobre todos los registros.</p>
                <Barras items={D.codigo.map(c => ({ n: c.significado, v: c.registros, c: ['#c5d0da', '#1f6fb2', '#f0a829', '#9fb3c4'][c.codigo_coip] }))} />
                <p className="n" style={{ marginTop: 12 }}>El modelo predice solo el <b>código 1</b>.</p></div>
            </div>
          </section>)}

        {sec === 'mapa' && (mat ? <MapaVivo datos={D} pron1={p1} mat={mat} sel={par} onSel={setPar} onTendencia={n => { setPar(n); ir('tend'); }} dark={oscuro} /> : <div className="card">Cargando mapa…</div>)}

        {sec === 'pron' && <Pronostico D={D} pron={pron} p1={p1} umbral={umbral} setUmbral={setUmbral} onParroquia={verParroquia} />}
        {sec === 'tend' && <Tendencia D={D} par={par} setPar={setPar} />}
        {sec === 'modelos' && <Modelos D={D} />}
        {sec === 'abig' && <Abigeato D={D} />}
        {sec === 'metodo' && <Metodo />}
      </main>

      <nav className="bottom">{SECC.slice(0, 5).map(([k, t]) => <a key={k} className={sec === k ? 'on' : ''} onClick={() => ir(k)}><svg viewBox="0 0 24 24" fill="currentColor"><path d={ICO[k]} /></svg>{t.split(' ')[0]}</a>)}</nav>
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
function Pronostico({ D, pron, p1, umbral, setUmbral, onParroquia }) {
  const [h, setH] = useState(1), [q, setQ] = useState(''), [ord, setOrd] = useState(['indice', -1]);
  const sems = [...new Set(D.pron.map(p => p.semana_inicio))].sort();
  const filas = pron.filter(p => p.horizonte === h && nom(p.parroquia_corta).toLowerCase().includes(q.toLowerCase())).sort((a, b) => ord[1] * (typeof a[ord[0]] === 'string' ? a[ord[0]].localeCompare(b[ord[0]]) : a[ord[0]] - b[ord[0]]));
  const o = k => () => setOrd(ord[0] === k ? [k, -ord[1]] : [k, -1]);
  const csv = () => { const c = 'parroquia,semana_inicio,prediccion,rango_bajo,rango_alto,prom_52_sem,prob_al_menos_1,indice,alerta\n' + filas.map(r => [r.parroquia_corta, r.semana_inicio, r.prediccion, r.rango_bajo, r.rango_alto, r.media_52_semanas, r.prob_al_menos_1, r.indice, r.alerta].join(',')).join('\n'); const a = document.createElement('a'); a.href = URL.createObjectURL(new Blob([c], { type: 'text/csv' })); a.download = 'pronostico_stanford.csv'; a.click(); };
  return (
    <section>
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="row" style={{ margin: 0, justifyContent: 'space-between' }}>
          <div style={{ flex: 1, minWidth: 260 }}><h3>¿Qué tan sensible quieres la alerta?<Info t="Índice = pronóstico / promedio de las últimas 52 semanas × 100. Alerta Alta si el índice supera 100 + el porcentaje elegido." /></h3>
            <p className="n" style={{ margin: 0 }}>Alerta <b>Alta</b> cuando el pronóstico supera el promedio anual en <b>{umbral} %</b> o más. El servidor recalcula todo al mover la barra.</p></div>
          <div style={{ width: 280 }}><input type="range" min="5" max="60" step="5" value={umbral} onChange={e => setUmbral(+e.target.value)} /><div className="lim"><span>Más alertas</span><span>Menos alertas</span></div></div>
        </div>
      </div>
      <div className="grid g3">
        {p1.slice().sort((a, b) => b.indice - a.indice).map(p => (
          <button key={p.parroquia_corta} className="card tarj" style={p.alerta !== 'Normal' ? { borderColor: '#f3b9ac' } : null} onClick={() => onParroquia(p.parroquia_corta)}>
            <div className="row" style={{ justifyContent: 'space-between', margin: 0 }}><h3 style={{ margin: 0 }}>{nom(p.parroquia_corta)}{p.zona_foco ? ' ★' : ''}</h3><span className={p.alerta === 'Alta' ? 'pulse' : ''}><Badge a={p.alerta} /></span></div>
            <div className="num" style={{ fontSize: 30, marginTop: 8 }}>{fmt(p.prediccion, p.prediccion < 10 ? 1 : 0)}<span className="u"> delitos esperados</span></div>
            <div className="n" style={{ margin: '4px 0 0' }}>Rango {fmt(p.rango_bajo, 1)} – {fmt(p.rango_alto, 1)} · Prob. ≥1: <b>{p.prob_al_menos_1} %</b></div>
            <div className="n" style={{ margin: '10px 0 0', display: 'flex', justifyContent: 'space-between' }}><span>Índice vs promedio anual</span><b style={{ color: 'var(--ink)' }}>{p.indice}</b></div>
            <div className="bar" style={{ margin: '4px 0' }}><span className="tr"><span className="fi" style={{ width: `${Math.min(100, p.indice / 1.5)}%`, background: COL[p.alerta] }} /></span></div>
            <div className="n" style={{ margin: 0, color: 'var(--azul)' }}>Ver en el mapa →</div>
          </button>))}
      </div>
      <div className="card" style={{ marginTop: 16 }}>
        <h3>Detalle: próximas 4 semanas</h3>
        <div className="row"><select value={h} onChange={e => setH(+e.target.value)}>{sems.map((s, i) => <option key={s} value={i + 1}>Semana {i + 1}: desde {new Date(s + 'T12:00').toLocaleDateString('es-EC', { day: 'numeric', month: 'short', year: 'numeric' })}</option>)}</select>
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
          series={[{ n: 'Real', c: '#1f6fb2', y: m.inc.map((v, i) => (m.tipo[i] === 'Real' ? v : null)) }, { n: 'Pronóstico', c: '#e0533a', dash: 1, y: m.inc.map((v, i) => (i >= ic - 1 ? v : null)) }]}
          bands={[{ lo: m.b95, hi: m.a95, c: '#e0533a', o: 0.1 }, { lo: m.b80, hi: m.a80, c: '#e0533a', o: 0.18 }]} />
      : <LineChart h={340} x={x} xlab={lab} corte={ic} series={[{ n: 'Real (12 meses)', c: '#1f6fb2', y: T.acum12.map((v, i) => (m.tipo[i] === 'Real' ? v : null)) }, { n: 'Pronóstico (12 meses)', c: '#e0533a', dash: 1, y: T.acum12.map((v, i) => (i >= ic - 1 ? v : null)) }]} />;
  }
  if (modo === 'comp') {
    const b = meses.indexOf('2025-12');
    grafico = <LineChart h={340} x={meses.map(mesTxt)} xlab={lab} corte={meses.indexOf('2026-10')} series={comp.map(q => { const r = roll(D.mensual[q].inc); return { n: nom(q), c: PAL[pars.indexOf(q)], y: r.map(v => (v == null ? null : (v / (r[b] || 1)) * 100)) }; })} />;
  }
  return (
    <section>
      <div className="card">
        <div className="row"><h3 style={{ margin: 0 }}>Tendencia mensual hasta 2029</h3>
          <select value={p} onChange={e => setPar(e.target.value)}>{pars.map(q => <option key={q} value={q}>{nom(q)}{FOCO.includes(q) ? ' ★' : ''}</option>)}</select>
          <div className="seg">{[['mes', 'Mensual'], ['acum', 'Últimos 12 meses'], ['comp', 'Comparar']].map(([k, t]) => <button key={k} className={modo === k ? 'on' : ''} onClick={() => setModo(k)}>{t}</button>)}</div>
          {T && modo !== 'comp' && <span className="chip">Método ganador: <b>{T.serie.modelo}</b></span>}</div>
        {modo === 'comp' && <div className="pills">{pars.map(q => { const on = comp.includes(q); return <span key={q} className={`pill ${on ? 'on' : ''}`} style={on ? { background: PAL[pars.indexOf(q)], borderColor: PAL[pars.indexOf(q)] } : null} onClick={() => setComp(on ? comp.filter(z => z !== q) : [...comp, q])}>{nom(q)}</span>; })}</div>}
        <p className="n" style={{ marginTop: 10 }}>{modo === 'mes' ? 'Línea sólida = datos reales; punteada = pronóstico; bandas = rango probable al 80 % y 95 %. Con pocos casos las bandas son amplias: es lo honesto.' : modo === 'acum' ? 'Suma móvil de 12 meses: quita la estacionalidad y muestra la tendencia.' : 'Índice: 100 = delitos de los 12 meses que terminan en dic-2025. Permite comparar parroquias grandes y pequeñas.'}</p>
        {grafico || <p className="n">Cargando…</p>}
      </div>
      <div className="grid g2" style={{ marginTop: 16 }}>
        <div className="card"><h3>Delitos por año · {nom(p)}</h3>
          <Tabla cols={[{ t: 'Año', f: r => r.a }, { t: 'Delitos', r: 1, f: r => fmt(r.v) }, { t: 'Tipo', f: r => r.t }]} rows={YRS.map(y => ({ a: y, v: fil[y], t: +y <= 2025 ? 'Real' : +y === 2026 ? 'Real + pronóstico' : 'Pronóstico' }))} /></div>
        <div className="card"><h3>Cambio 2025 → 2029</h3><p className="n">Solo parroquias con 5 o más delitos en 2025. Pocos casos = porcentajes muy variables.</p>
          <Barras fmtv={v => fmt(v, 1) + ' %'} items={D.cambio.filter(c => c['2025'] >= 5).sort((a, b) => a.cambio_2025_2029_pct - b.cambio_2025_2029_pct).map(c => ({ n: `${nom(c.parroquia_corta)} (${c['2025']}→${c['2029']})`, v: Math.abs(c.cambio_2025_2029_pct), c: c.cambio_2025_2029_pct > 0 ? '#e0533a' : '#2f86b8' }))} />
          <div className="leg"><span><i style={{ background: '#2f86b8' }} />Baja</span><span><i style={{ background: '#e0533a' }} />Sube</span></div></div>
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
      <div className="card" style={{ marginTop: 16 }}><h3>Límite del azar<Info t="Aun un modelo perfecto falla porque los delitos tienen una parte aleatoria." /></h3>
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
