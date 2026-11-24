'use client';
import { useCallback, useEffect, useMemo, useState } from 'react';
import dynamic from 'next/dynamic';
import { Barras, Columnas, LineChart } from './Charts';
import { api } from '../lib/api';
import LOG from '../lib/logica';
import { PAL, clase, leyendaSec } from '../lib/mapas';
import { ESTADO, FOCO, esFoco, fmt, fmtN, mesLargo, mesTxt, nom, probTxt, ruido, semana } from '../lib/util';

/* Leaflet solo funciona en el navegador */
const MapaLeaflet = dynamic(() => import('./MapaLeaflet'), { ssr: false, loading: () => <div className="lmapa lm-vacio">Cargando mapa…</div> });

const TABS = [['semana', 'Esta semana'], ['mapas', 'Mapas'], ['parroquias', 'Parroquias'], ['futuro', 'Hacia 2029'], ['metodo', 'Cómo se calcula']];
const YRS = ['2022', '2023', '2024', '2025', '2026', '2027', '2028', '2029'];
const ORD = { Alta: 0, Media: 1, Normal: 2 };
const ESC_INFO = [
  { k: 'base', fila: 'Base (Sonia)', t: 'Catálogo COIP (oficial)', d: 'Solo lo que el catálogo COIP de Sonia Calle marca como delito explícito (código 1). Es el resultado oficial del proyecto.' },
  { k: 'A', fila: 'A', t: 'Ampliado A', d: 'Suma 15 tipos que el COIP nombra expresamente (violencia física familiar, drogas, armas de fuego, abandono, delitos sexuales…). Confianza alta.' },
  { k: 'AB', fila: 'A+B', t: 'Ampliado A+B', d: 'Suma además 15 tipos probables (agresiones, personas heridas, daños, fraude). Confianza media o baja.' },
  { k: 'ED', fila: 'ED', t: 'Reglas del equipo', d: 'Todo lo que las reglas de palabras clave del equipo llaman «delito» (método anterior al catálogo). Es una segunda opinión independiente.' },
];

/* ---------- piezas pequeñas ---------- */
const Estado = ({ a, chico }) => <span className={`estado e-${a} ${chico ? 'chico' : ''}`}><i />{ESTADO[a].t}</span>;
const Foco = () => <span className="tag-foco" title="Parroquia foco del proyecto">foco</span>;
function Icono({ d }) { return <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={d} /></svg>; }
const I = {
  sol: 'M12 4V2m0 20v-2m8-8h2M2 12h2m13.66-5.66 1.41-1.41M4.93 19.07l1.41-1.41m0-11.32L4.93 4.93m14.14 14.14-1.41-1.41M12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8z',
  luna: 'M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z',
  flecha: 'M5 12h14m-6-6 6 6-6 6',
  atras: 'M19 12H5m6 6-6-6 6-6',
  bajar: 'M12 4v12m-5-5 5 5 5-5M5 20h14',
};

function Selector({ semanas, sem, setSem }) {
  return (
    <div className="semanas" role="tablist" aria-label="Elegir semana">
      {semanas.map(w => (
        <button key={w.h} role="tab" aria-selected={sem === w.h} className={sem === w.h ? 'on' : ''} onClick={() => setSem(w.h)}>
          <span className="s-et">{w.etiqueta}</span>
          <span className="s-f">{w.corto}</span>
          <span className="s-a">{w.altas ? <><i className="d-Alta" />{w.altas} en alerta</> : w.medias ? <><i className="d-Media" />{w.medias} en atención</> : <><i className="d-Normal" />todo normal</>}</span>
        </button>))}
    </div>
  );
}

/* ---------- tablero ---------- */
export default function Dashboard({ datos: D, pronInicial }) {
  const [tab, setTab] = useState('semana');
  const [tema, setTema] = useState(null);
  const [par, setPar] = useState('CUBIJIES');
  const [umbral, setUmbral] = useState(25);
  const [esc, setEsc] = useState('base');
  const [pron, setPron] = useState(pronInicial);
  const [fuente, setFuente] = useState('servidor');
  const [sem, setSem] = useState(null);
  const [hoy, setHoy] = useState(null);

  useEffect(() => {
    setHoy(new Date());
    try { const t = localStorage.getItem('tema'); if (t) setTema(t); } catch { /* sin almacenamiento */ }
    const leer = () => { const h = location.hash.slice(1); if (TABS.some(t => t[0] === h)) setTab(h); };
    leer(); window.addEventListener('hashchange', leer);
    return () => window.removeEventListener('hashchange', leer);
  }, []);
  useEffect(() => {
    if (!tema) return; document.documentElement.dataset.theme = tema;
    try { localStorage.setItem('tema', tema); } catch { /* sin almacenamiento */ }
  }, [tema]);
  /* tema efectivo (elegido o del sistema): los mapas cambian su fondo y colores */
  const [oscuro, setOscuro] = useState(false);
  useEffect(() => {
    const mq = matchMedia('(prefers-color-scheme: dark)');
    const f = () => setOscuro(tema ? tema === 'dark' : mq.matches);
    f(); mq.addEventListener('change', f); return () => mq.removeEventListener('change', f);
  }, [tema]);
  useEffect(() => {
    let vivo = true;
    api('pronostico', { umbral, esc: esc === 'base' ? '' : esc }, D).then(r => { if (vivo) { setPron(r.data.filas); setFuente(r.fuente); } });
    return () => { vivo = false; };
  }, [umbral, esc, D]);

  const ir = useCallback(k => { setTab(k); if (location.hash !== '#' + k) history.pushState(null, '', '#' + k); window.scrollTo({ top: 0 }); }, []);
  const verParroquia = useCallback(n => { setPar(n); ir('parroquias'); }, [ir]);
  const alternarTema = () => {
    const actual = tema || (matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    setTema(actual === 'dark' ? 'light' : 'dark');
  };

  /* Semanas pronosticadas que aún no terminan; la que contiene hoy es «Esta semana» */
  const semanas = useMemo(() => {
    const hs = [...new Set(pron.map(p => p.horizonte))].sort((a, b) => a - b);
    const todas = hs.map(h => {
      const f = pron.filter(p => p.horizonte === h);
      return { h, ...semana(f[0].semana_inicio), altas: f.filter(p => p.alerta === 'Alta').length, medias: f.filter(p => p.alerta === 'Media').length };
    });
    if (!hoy) return todas.slice(0, 5).map(w => ({ ...w, etiqueta: `Semana ${w.h}` }));
    const t = hoy.getTime(), fin = w => w.fin.getTime() + 86400000;
    const vivas = todas.filter(w => fin(w) > t), lista = (vivas.length ? vivas : todas.slice(-1)).slice(0, 5);
    const hay = lista[0].ini.getTime() <= t;   // la primera semana contiene hoy
    return lista.map((w, i) => {
      const n = hay ? i : i + 1;
      return { ...w, actual: hay && i === 0, etiqueta: n === 0 ? 'Esta semana' : n === 1 ? 'La próxima' : `En ${n} semanas` };
    });
  }, [pron, hoy]);
  const sw = semanas.find(w => w.h === sem) || semanas[0];
  const p1 = useMemo(() => pron.filter(p => p.horizonte === sw.h), [pron, sw]);
  const escInfo = ESC_INFO.find(x => x.k === esc);
  const fechaDatos = new Date(D.generado + 'T12:00').toLocaleDateString('es-EC', { day: 'numeric', month: 'long', year: 'numeric' });

  return (
    <div className="app">
      <a className="saltar" href="#contenido">Saltar al contenido</a>
      <div className="fondo" aria-hidden="true">
        <img className="f-stanford" src="/fondo-stanford.png" alt="" />
        <img className="f-unach" src="/fondo-unach.png" alt="" />
      </div>
      <header className="cab">
        <div className="logo">
          <span className="logos">
            <img className="e-stanford" src="/emblema-stanford.png" alt="Instituto Superior Universitario Stanford" width="48" height="48" />
            <img className="e-unach" src="/emblema-unach.png" alt="Universidad Nacional de Chimborazo · Ciencia de Datos e IA" width="48" height="48" />
          </span>
          <div><b>Proyecto STANFORD</b><span>Delitos en Riobamba · UNACH</span></div>
        </div>
        <nav className="tabs" aria-label="Secciones">
          {TABS.map(([k, t]) => <button key={k} className={tab === k ? 'on' : ''} aria-current={tab === k ? 'page' : undefined} onClick={() => ir(k)}>{t}</button>)}
        </nav>
        <button className="icono" onClick={alternarTema} aria-label="Cambiar entre tema claro y oscuro" title="Tema claro u oscuro">
          <span className="i-luna"><Icono d={I.luna} /></span><span className="i-sol"><Icono d={I.sol} /></span>
        </button>
      </header>
      {esc !== 'base' && (
        <div className="aviso-esc" role="status">Estás viendo la definición <b>{escInfo.t}</b>, que no es la oficial. <button onClick={() => setEsc('base')}>Volver al catálogo COIP oficial</button></div>
      )}

      <main id="contenido">
        {tab === 'semana' && <Semana D={D} pron={pron} p1={p1} semanas={semanas} sw={sw} setSem={setSem} verParroquia={verParroquia} ir={ir} oscuro={oscuro} />}
        {tab === 'mapas' && <Mapas D={D} p1={p1} semanas={semanas} sw={sw} setSem={setSem} verParroquia={verParroquia} oscuro={oscuro} />}
        {tab === 'parroquias' && <Parroquia D={D} pron={pron} p1={p1} sw={sw} semanas={semanas} setSem={setSem} par={par} setPar={setPar} oscuro={oscuro} />}
        {tab === 'futuro' && <Futuro D={D} verParroquia={verParroquia} oscuro={oscuro} />}
        {tab === 'metodo' && <Metodo D={D} pron={pron} sw={sw} esc={esc} setEsc={setEsc} umbral={umbral} setUmbral={setUmbral} />}
      </main>

      <footer className="pie">
        <p>Fuente: Servicio Integrado de Seguridad ECU 911 (datos abiertos, julio 2021 – septiembre 2026), agregados por parroquia y semana. Delitos explícitos según el catálogo COIP.</p>
        <p>Resultados de los scripts de R del proyecto, actualizados el {fechaDatos} · Datos {fuente === 'API' ? 'servidos por la API del tablero' : 'calculados en el navegador'} · Proyecto STANFORD, Universidad Nacional de Chimborazo · Carrera de Ciencia de Datos e IA.</p>
      </footer>
    </div>
  );
}

/* ---------- 1. Esta semana ---------- */
/* Recuadro del mapa con el pronóstico de una parroquia en la semana elegida */
function infoSemana(p) {
  if (!p) return null;
  return (<>
    <b className="lmi-t">{nom(p.parroquia_corta)}</b><Estado a={p.alerta} chico />
    <div className="lmi-f">{p.media_52_semanas < 1 ? <>Probabilidad de al menos un delito: <b>{fmt(p.prob_al_menos_1)} %</b></> : <>Se esperan <b>{fmtN(p.prediccion)}</b> delitos (habitual {fmtN(p.media_52_semanas)})</>}</div>
  </>);
}

function Semana({ D, p1, semanas, sw, setSem, verParroquia, ir, oscuro }) {
  const total = p1.reduce((s, p) => s + p.prediccion, 0), habitual = p1.reduce((s, p) => s + p.media_52_semanas, 0);
  const dif = (total / habitual - 1) * 100;
  const altas = p1.filter(p => p.alerta === 'Alta'), medias = p1.filter(p => p.alerta === 'Media');
  const lista = p1.slice().sort((a, b) => ORD[a.alerta] - ORD[b.alerta] || b.prediccion - a.prediccion);
  const porNom = Object.fromEntries(p1.map(p => [p.parroquia_corta, p]));
  const nombres = l => l.map(p => nom(p.parroquia_corta)).join(l.length === 2 ? ' y ' : ', ');
  const [sel, setSel] = useState(null);
  const csv = () => {
    const c = 'parroquia,semana_inicio,prediccion,rango_bajo,rango_alto,promedio_52_semanas,prob_al_menos_1,indice,estado\n' + lista.map(r => [nom(r.parroquia_corta), r.semana_inicio, r.prediccion, r.rango_bajo, r.rango_alto, r.media_52_semanas, r.prob_al_menos_1, r.indice, ESTADO[r.alerta].t].join(',')).join('\n');
    const a = document.createElement('a'); a.href = URL.createObjectURL(new Blob(['﻿' + c], { type: 'text/csv' })); a.download = `pronostico_${p1[0].semana_inicio}.csv`; a.click();
  };
  return (
    <>
      <section className="hero">
        <Selector semanas={semanas} sem={sw.h} setSem={setSem} />
        <h1>
          {sw.largo.charAt(0).toUpperCase() + sw.largo.slice(1)} se esperan unos <em>{fmt(total)} delitos</em> en el cantón Riobamba
          {Math.abs(dif) < 5 ? ', similar a una semana habitual.' : dif > 0 ? `, un ${fmt(dif)} % más que en una semana habitual.` : `, un ${fmt(-dif)} % menos que en una semana habitual.`}
        </h1>
        <p className="lead">
          {altas.length ? <><b>{nombres(altas)}</b> {altas.length > 1 ? 'están' : 'está'} en alerta: se espera bastante más de lo habitual. </> : null}
          {medias.length ? <><b>{nombres(medias)}</b> {medias.length > 1 ? 'piden' : 'pide'} atención. </> : null}
          {!altas.length && !medias.length ? 'Las 12 parroquias están dentro de lo habitual para la época.' : 'El resto está dentro de lo habitual para la época.'}
        </p>
      </section>

      <section className="foco-fila" aria-label="Parroquias foco del proyecto">
        {FOCO.map(n => { const p = porNom[n]; if (!p) return null; return (
          <button key={n} className="foco-c" onClick={() => verParroquia(n)}>
            <div className="foco-pct"><b>{fmt(p.prob_al_menos_1)}</b><span>%</span></div>
            <div>
              <h3>{nom(n)} <Foco /></h3>
              <p>Es <b>{probTxt(p.prob_al_menos_1)}</b> que ocurra al menos un delito esta semana. En promedio hay {fmt(p.media_52_semanas, 1)} por semana.</p>
            </div>
            <span className="ir"><Icono d={I.flecha} /></span>
          </button>); })}
      </section>

      <section className="panel mapa-lista">
        <div className="ml-mapa">
          <div className="ml-cab"><h2>Mapa de la semana</h2></div>
          <MapaLeaflet geo={D.geo} sel={sel} atenuar={false} onSel={verParroquia} oscuro={oscuro} alto={500} titulo="Mapa del estado de cada parroquia en la semana elegida"
            color={n => PAL.estado[oscuro ? 'oscuro' : 'claro'][porNom[n]?.alerta || 'Normal']}
            etiqueta={n => porNom[n] ? fmtN(porNom[n].prediccion) : ''} info={n => infoSemana(porNom[n])}
            leyenda={['Normal', 'Media', 'Alta'].map(a => [ESTADO[a].t, PAL.estado[oscuro ? 'oscuro' : 'claro'][a]])}>
            <span><i className="d-foco" />Foco</span>
          </MapaLeaflet>
          <p className="nota">El número bajo cada nombre es cuántos delitos se esperan en la semana. Toca una parroquia para ver su detalle; en «Mapas» hay más capas.</p>
        </div>
        <div className="ml-lista">
          <div className="ml-cab"><h2>Parroquia por parroquia</h2><button className="enlace" onClick={csv}><Icono d={I.bajar} />CSV</button></div>
          <ul className="lista-p">
            {lista.map(p => (
              <li key={p.parroquia_corta}>
                <button onClick={() => verParroquia(p.parroquia_corta)} onPointerEnter={() => setSel(p.parroquia_corta)} onPointerLeave={() => setSel(null)} onFocus={() => setSel(p.parroquia_corta)} onBlur={() => setSel(null)}>
                  <span className="lp-n">{nom(p.parroquia_corta)}{esFoco(p.parroquia_corta) && <Foco />}</span>
                  <Estado a={p.alerta} chico />
                  <span className="lp-v"><b>{fmtN(p.prediccion)}</b><small>habitual {fmtN(p.media_52_semanas)}</small></span>
                </button>
              </li>))}
          </ul>
        </div>
      </section>

      <section className="como">
        <h2>Cómo leer el estado</h2>
        <dl>
          <div><dt><Estado a="Normal" /></dt><dd>El pronóstico está dentro de lo que suele pasar en esa parroquia.</dd></div>
          <div><dt><Estado a="Media" /></dt><dd>Se espera algo más de lo habitual. Conviene mirar con atención.</dd></div>
          <div><dt><Estado a="Alta" /></dt><dd>Se espera bastante más de lo habitual y la diferencia es mayor que la variación normal.</dd></div>
        </dl>
        <p className="nota">«Habitual» es el promedio de las últimas 52 semanas. Son una guía para decidir dónde mirar primero, no una certeza. <button className="enlace" onClick={() => ir('metodo')}>Cómo se calcula</button></p>
      </section>
    </>
  );
}

/* ---------- 2. Parroquias ---------- */
function Parroquia({ D, pron, p1, sw, semanas, setSem, par, setPar, oscuro }) {
  const orden = ['RIOBAMBA', ...FOCO, ...Object.keys(D.mensual).filter(n => n !== 'RIOBAMBA' && !FOCO.includes(n)).sort()];
  const p = p1.find(x => x.parroquia_corta === par), g = D.geo.find(x => x.nom === par), c = D.cambio.find(x => x.parroquia_corta === par);
  const az = D.azar.find(x => x.parroquia_corta === par), ser = D.mensual[par];
  const [desde, setDesde] = useState('2024');
  const sems = pron.filter(x => x.parroquia_corta === par).sort((a, b) => a.horizonte - b.horizonte);
  const ip = ser.tipo.indexOf('Pronóstico');
  const idx = ser.mes.map((_, i) => i).filter(i => ser.mes[i] >= (desde === 'todo' ? '0' : desde + '-01'));
  const k = az ? az.MAE_modelo / Math.max(az.MAE_modelo_perfecto, 0.001) : 1;
  const conf = k <= 1.15 ? ['El modelo acierta casi lo máximo que los datos permiten.', 'ok'] : k <= 1.35 ? ['El modelo está cerca del máximo posible.', 'warn'] : ['El modelo todavía tiene margen de mejora aquí.', 'bad'];
  const pocos = p.media_52_semanas < 1;
  const top2 = (() => {
    const s = Array(12).fill(0), n = Array(12).fill(0);
    ser.mes.forEach((m, i) => { if (ser.tipo[i] === 'Real') { s[+m.slice(5) - 1] += ser.inc[i] || 0; n[+m.slice(5) - 1]++; } });
    return s.map((v, i) => [v / (n[i] || 1), i]).sort((a, b) => b[0] - a[0]).slice(0, 2).map(x => ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'][x[1]]);
  })();
  const lab = idx.filter(i => ser.mes[i].endsWith('-01')).map(i => [idx.indexOf(i), ser.mes[i].slice(0, 4)]);
  const corte = idx.indexOf(ip);
  const yf = v => fmt(v, v < 10 && v % 1 ? 1 : 0);
  const iActual = sems.findIndex(x => x.horizonte === sw.h);

  return (
    <div className="parr">
      <aside className="parr-nav" aria-label="Elegir parroquia">
        <label className="sr" htmlFor="sel-par">Parroquia</label>
        <select id="sel-par" className="parr-sel" value={par} onChange={e => setPar(e.target.value)}>
          {orden.map(n => <option key={n} value={n}>{nom(n)}{esFoco(n) ? ' (foco)' : ''}</option>)}
        </select>
        <ul>
          {orden.map(n => { const q = p1.find(x => x.parroquia_corta === n); return (
            <li key={n}><button className={par === n ? 'on' : ''} aria-current={par === n ? 'true' : undefined} onClick={() => setPar(n)}>
              <i className={`d-${q?.alerta || 'Normal'}`} />{nom(n)}{esFoco(n) && <Foco />}
            </button></li>); })}
        </ul>
      </aside>

      <div className="parr-cont">
        <section className="hero chico">
          <p className="meta">{n2(g.area)} km² · {par === 'RIOBAMBA' ? 'zona urbana' : 'parroquia rural'}{g.foco ? ' · parroquia foco del proyecto' : ''}</p>
          <h1 className="h-parr">{nom(par)}</h1>
          <Selector semanas={semanas} sem={sw.h} setSem={setSem} />
          <div className="veredicto">
            {pocos ? (
              <p>Del {sw.corto}: es <b>{probTxt(p.prob_al_menos_1)}</b> que ocurra al menos un delito ({fmt(p.prob_al_menos_1)} %). Aquí hay pocos casos, por eso hablamos de probabilidad y no de una cifra exacta.</p>
            ) : (
              <p>Del {sw.corto} se esperan unos <b>{fmtN(p.prediccion)} delitos</b> (probablemente entre {fmtN(p.rango_bajo)} y {fmtN(p.rango_alto)}). Lo habitual es {fmtN(p.media_52_semanas)} por semana.</p>
            )}
            <Estado a={p.alerta} />
          </div>
        </section>

        <div className="cifras">
          <div><span>Delitos en 2025</span><b>{fmt(c['2025'])}</b></div>
          <div><span>Esperados en 2029</span><b>{fmt(c['2029'])}</b></div>
          <div><span>Cambio</span><b className={ruido(c) ? '' : c.cambio_2025_2029_pct > 0 ? 'sube' : 'baja'}>{ruido(c) ? 'estable' : `${c.cambio_2025_2029_pct > 0 ? '+' : ''}${fmt(c.cambio_2025_2029_pct)} %`}</b></div>
          <div><span>Promedio semanal</span><b>{fmt(p.media_52_semanas, p.media_52_semanas < 10 ? 1 : 0)}</b></div>
        </div>

        <section className="panel">
          <h2>Dónde queda</h2>
          <p className="nota">{nom(par)} resaltada sobre el mapa del cantón. Toca otra parroquia para cambiar; con «Satélite» se ve el terreno.</p>
          <MapaLeaflet geo={D.geo} sel={par} onSel={setPar} oscuro={oscuro} alto={340} enfocar nombres atenuar={false} titulo={`Ubicación de ${nom(par)}`}
            color={n => (n === par ? (oscuro ? '#62a0d4' : '#2f78b7') : oscuro ? '#3a434d' : '#d9d4c9')}
            info={n => { const q = p1.find(x => x.parroquia_corta === n), gg = D.geo.find(x => x.nom === n); return <><b className="lmi-t">{nom(n)}</b>{q && <Estado a={q.alerta} chico />}<div className="lmi-f">{n2(gg.area)} km² · {fmt(D.cambio.find(x => x.parroquia_corta === n)['2025'])} delitos en 2025</div></>; }} />
        </section>

        <section className="panel">
          <h2>Las próximas semanas</h2>
          {pocos ? <>
          <p className="nota">Probabilidad de que ocurra al menos un delito en cada semana. Con tan pocos casos, esta es la forma más honesta de leer el pronóstico. La semana elegida está marcada.</p>
          <LineChart h={220} label={`Probabilidad semanal en ${nom(par)}`} x={sems.map(s => 'Semana del ' + semana(s.semana_inicio).corto)}
            xlab={sems.map((s, i) => [i, semana(s.semana_inicio).desde]).filter((_, i) => i % 2 === 0 || i === iActual)} yfmt={v => fmt(v) + ' %'}
            series={[{ n: 'Probabilidad', c: 'var(--acc)', y: sems.map(s => s.prob_al_menos_1) }]} marca={iActual >= 0 ? { s: 0, i: iActual } : null} />
          </> : <>
          <p className="nota">Delitos esperados por semana (línea), su rango probable (sombra) y lo habitual (línea gris). La semana elegida está marcada.</p>
          <LineChart h={240} label={`Pronóstico semanal de ${nom(par)}`} x={sems.map(s => 'Semana del ' + semana(s.semana_inicio).corto)}
            xlab={sems.map((s, i) => [i, semana(s.semana_inicio).desde]).filter((_, i) => i % 2 === 0 || i === iActual)}
            yfmt={yf} bands={[{ lo: sems.map(s => s.rango_bajo), hi: sems.map(s => s.rango_alto), c: 'var(--acc)', o: 0.14 }]}
            series={[{ n: 'Habitual', c: 'var(--mut2)', dash: 1, w: 1.5, y: sems.map(s => s.media_52_semanas) }, { n: 'Esperados', c: 'var(--acc)', y: sems.map(s => s.prediccion) }]} marca={iActual >= 0 ? { s: 1, i: iActual } : null} />
          </>}
        </section>

        <section className="panel">
          <div className="ml-cab">
            <h2>Mes a mes, hasta 2029</h2>
            <div className="seg" role="group" aria-label="Periodo">{[['2024', 'Desde 2024'], ['todo', 'Desde 2021']].map(([v, t]) => <button key={v} className={desde === v ? 'on' : ''} aria-pressed={desde === v} onClick={() => setDesde(v)}>{t}</button>)}</div>
          </div>
          <p className="nota">Línea continua: lo que registró el ECU 911. Línea punteada: lo que calcula el modelo ({ser.modelo}). La sombra muestra dónde caería la cifra 8 de cada 10 veces.</p>
          <LineChart h={300} label={`Delitos por mes en ${nom(par)}`} x={idx.map(i => mesTxt(ser.mes[i]))} xlab={lab} corte={corte} yfmt={yf}
            bands={[{ lo: idx.map(i => ser.b95[i]), hi: idx.map(i => ser.a95[i]), c: 'var(--acc2)', o: 0.08 }, { lo: idx.map(i => ser.b80[i]), hi: idx.map(i => ser.a80[i]), c: 'var(--acc2)', o: 0.16 }]}
            series={[{ n: 'Registrados', c: 'var(--acc)', y: idx.map(i => (ser.tipo[i] === 'Real' ? ser.inc[i] : null)) }, { n: 'Pronóstico', c: 'var(--acc2)', dash: 1, y: idx.map(i => (i >= ip - 1 ? ser.inc[i] : null)) }]} />
          <p className="resumen">
            En {nom(par)} hubo <b>{fmt(c['2025'])}</b> delitos en 2025 y se esperan <b>{fmt(c['2029'])}</b> en 2029: {ruido(c) ? <>se mantendría <b>estable</b>, porque la diferencia cabe dentro de la variación normal.</> : <>{c.cambio_2025_2029_pct > 0 ? 'subiría' : 'bajaría'} un <b>{fmt(Math.abs(c.cambio_2025_2029_pct))} %</b>.</>}
            {top2[0] && c['2025'] >= 12 ? <> Los meses con más casos suelen ser <b>{top2[0]}</b> y <b>{top2[1]}</b>.</> : null}
          </p>
          <div className="anios" role="table" aria-label="Delitos por año">
            {YRS.map(y => <div key={y} role="row" className={+y >= 2026 ? 'pr' : ''}><span role="cell">{y}</span><b role="cell">{fmt(c[y])}</b></div>)}
          </div>
          <p className="nota">2026 junta nueve meses registrados y tres pronosticados; de 2027 en adelante es pronóstico.</p>
        </section>

        {az && (
          <section className="panel conf">
            <h2>¿Qué tan confiable es aquí?</h2>
            <p><span className={`punto ${conf[1]}`} />{conf[0]} En el último año (52 semanas de prueba) se equivocó en promedio <b>{fmt(az.MAE_modelo, 2)}</b> delitos por semana; el mínimo posible con estos datos era <b>{fmt(az.MAE_modelo_perfecto, 2)}</b>.</p>
            {pocos && <p className="nota">Con tan pocos casos por semana, cualquier modelo tendrá un error relativo alto. Eso no significa que esté mal: casi no hay casos que predecir.</p>}
          </section>
        )}
      </div>
    </div>
  );
}
const n2 = v => fmt(v, v < 100 ? 1 : 0);

/* ---------- 3. Hacia 2029 ---------- */
/* Color del cambio 2025→2029 (gris si cabe en la variación normal) */
const colCambio = (c, oscuro) => {
  const P = PAL.cambio[oscuro ? 'oscuro' : 'claro'], v = c.cambio_2025_2029_pct;
  if (c['2025'] < 5 || ruido(c)) return P.estable;
  return v > 10 ? P.subeMucho : v > 0 ? P.sube : v > -10 ? P.baja : P.bajaMucho;
};
const leyCambio = oscuro => { const P = PAL.cambio[oscuro ? 'oscuro' : 'claro']; return [['Sube más de 10 %', P.subeMucho], ['Sube hasta 10 %', P.sube], ['Estable', P.estable], ['Baja hasta 10 %', P.baja], ['Baja más de 10 %', P.bajaMucho]]; };
const txtCambio = c => (c['2025'] < 5 ? 'pocos casos' : ruido(c) ? 'estable' : `${c.cambio_2025_2029_pct > 0 ? '+' : ''}${fmt(c.cambio_2025_2029_pct)} %`);
const infoCambio = c => <><b className="lmi-t">{nom(c.parroquia_corta)}</b><div className="lmi-f">{fmt(c['2025'])} delitos en 2025 → <b>{fmt(c['2029'])}</b> en 2029 · {txtCambio(c)}</div></>;

function Futuro({ D, verParroquia, oscuro }) {
  const total = YRS.map(y => D.cambio.reduce((s, r) => s + (r[y] || 0), 0));
  const cambio = (total[7] / total[3] - 1) * 100;
  const filas = D.cambio.filter(c => c['2025'] >= 5).sort((a, b) => b.cambio_2025_2029_pct - a.cambio_2025_2029_pct);
  const estables = filas.filter(ruido).length;
  const bu = D.backtest.filter(b => b.zona === 'Urbana')[0], br = D.backtest.filter(b => b.zona === 'Rurales')[0];
  return (
    <>
      <section className="hero">
        <h1>Hacia 2029 se esperan unos <em>{fmt(total[7])} delitos al año</em> en el cantón, {Math.abs(cambio) < 3 ? 'prácticamente lo mismo que' : cambio < 0 ? `un ${fmt(-cambio)} % menos que` : `un ${fmt(cambio)} % más que`} los {fmt(total[3])} de 2025.</h1>
        <p className="lead">De {filas.length} parroquias con datos suficientes, {estables} se mantienen estables: su cambio cabe dentro de la variación normal de un año a otro.</p>
      </section>

      <section className="panel">
        <h2>Mapa del cambio 2025 → 2029</h2>
        <p className="nota">Rojo: se esperan más delitos; azul: menos; gris: estable o con muy pocos casos para afirmar un cambio.</p>
        <MapaLeaflet geo={D.geo} onSel={verParroquia} oscuro={oscuro} alto={460} titulo="Mapa del cambio de delitos de 2025 a 2029"
          color={n => colCambio(D.cambio.find(c => c.parroquia_corta === n), oscuro)} etiqueta={n => txtCambio(D.cambio.find(c => c.parroquia_corta === n))}
          info={n => infoCambio(D.cambio.find(c => c.parroquia_corta === n))} leyenda={leyCambio(oscuro)} />
      </section>

      <div className="dos">
        <section className="panel">
          <h2>Delitos por año en el cantón</h2>
          <p className="nota">Suma de las 12 parroquias. Las barras claras son pronóstico.</p>
          <Columnas label="Delitos por año en el cantón" items={YRS.map((y, i) => ({ n: y, l: y, v: total[i], c: i < 4 ? 'var(--acc)' : i === 4 ? 'var(--acc-mid)' : 'var(--acc-soft)' }))} />
        </section>
        <section className="panel">
          <h2>Cambio de 2025 a 2029 por parroquia</h2>
          <p className="nota">Solo parroquias con 5 o más delitos en 2025. <b>Gris</b>: el cambio cabe dentro de la variación normal, así que en la práctica se mantiene estable (con pocos casos, 5 delitos más ya son +30 %). Toca una para ver su detalle.</p>
          <Barras onClick={i => verParroquia(i.k)} items={filas.map(c => ({ k: c.parroquia_corta, n: nom(c.parroquia_corta), v: c.cambio_2025_2029_pct,
            txt: `${c.cambio_2025_2029_pct > 0 ? '+' : ''}${fmt(c.cambio_2025_2029_pct)} %`,
            c: ruido(c) ? 'var(--neutral)' : c.cambio_2025_2029_pct > 0 ? 'var(--bad)' : 'var(--acc)' }))} />
        </section>
      </div>

      <section className="panel prosa">
        <h2>¿Por qué las líneas se ven casi rectas después de 2027?</h2>
        <p>Lejos en el tiempo, el modelo solo puede proyectar el nivel normal de cada parroquia y una tendencia suave: los picos y valles del pasado no se pueden adivinar. Recta no significa «no cambiará»; significa que no hay una señal clara de cambio.</p>
        <p>Para elegir el método se probó cada uno con los últimos 24 meses. En Riobamba ganó <b>{bu.modelo.toLowerCase()}</b> (se equivoca un {fmt(bu.error_relativo_pct)} % por mes); en las parroquias rurales, <b>{br.modelo.toLowerCase()}</b>. Repetir el patrón de cada mes en parroquias con pocos casos acierta menos, porque ese patrón es casi pura variación.</p>
      </section>
    </>
  );
}

/* ---------- Mapas: varias capas sobre el mismo mapa ---------- */
const CAPAS = [
  { k: 'estado', t: 'Estado de la semana', d: 'Qué parroquias salen de lo habitual en la semana elegida.' },
  { k: 'prob', t: 'Probabilidad de un delito', d: 'Qué tan probable es que ocurra al menos un delito en la semana. Útil en parroquias con pocos casos.' },
  { k: 'densidad', t: 'Delitos por km²', d: 'Delitos de los 12 meses que terminan en el mes elegido, divididos para el área. Muévete en el tiempo hasta 2029.' },
  { k: 'cambio', t: 'Cambio hacia 2029', d: 'Cómo cambiarían los delitos de 2025 a 2029 según la tendencia del modelo.' },
  { k: 'abigeato', t: 'Robo de ganado', d: 'Casos de abigeato registrados entre julio de 2021 y septiembre de 2026.' },
];
const C_PROB = [10, 25, 50, 90], C_DENS = [0.1, 1, 5, 50], C_ABIG = [5, 10, 20, 30];

function Mapas({ D, p1, semanas, sw, setSem, verParroquia, oscuro }) {
  const [capa, setCapa] = useState('estado');
  const [sel, setSel] = useState(null);
  const mat = useMemo(() => LOG.mapa(D), [D]);
  const meses = mat.meses, iReal = D.mensual.RIOBAMBA.tipo.lastIndexOf('Real');
  const [mi, setMi] = useState(iReal);
  const [play, setPlay] = useState(false);
  useEffect(() => {
    if (!play) return;
    const t = setInterval(() => setMi(v => { if (v >= meses.length - 1) { setPlay(false); return v; } return v + 1; }), 450);
    return () => clearInterval(t);
  }, [play, meses.length]);
  useEffect(() => { if (capa !== 'densidad') setPlay(false); }, [capa]);

  const t = oscuro ? 'oscuro' : 'claro';
  const porNom = Object.fromEntries(p1.map(p => [p.parroquia_corta, p]));
  const area = Object.fromEntries(D.geo.map(g => [g.nom, g.area]));
  const abig = Object.fromEntries(D.abigeato['Por parroquia'].map(r => [r.parroquia_corta, r.casos]));
  const camb = Object.fromEntries(D.cambio.map(c => [c.parroquia_corta, c]));
  const futuro = meses[mi] > meses[iReal];

  /* cada capa: valor para ordenar, color, etiqueta en el mapa, recuadro y leyenda */
  const C = {
    estado: { v: n => -ORD[porNom[n].alerta] * 1000 + porNom[n].prediccion, col: n => PAL.estado[t][porNom[n].alerta], et: n => fmtN(porNom[n].prediccion), txt: n => ESTADO[porNom[n].alerta].t,
      info: n => infoSemana(porNom[n]), ley: ['Normal', 'Media', 'Alta'].map(a => [ESTADO[a].t, PAL.estado[t][a]]) },
    prob: { v: n => porNom[n].prob_al_menos_1, col: n => PAL.azul[t][clase(porNom[n].prob_al_menos_1, C_PROB)], et: n => fmt(porNom[n].prob_al_menos_1) + ' %', txt: n => fmt(porNom[n].prob_al_menos_1) + ' %',
      info: n => <><b className="lmi-t">{nom(n)}</b><div className="lmi-f">Es <b>{probTxt(porNom[n].prob_al_menos_1)}</b> que ocurra al menos un delito ({fmt(porNom[n].prob_al_menos_1)} %) del {sw.corto}.</div></>,
      ley: leyendaSec(C_PROB, PAL.azul[t], v => fmt(v), ' %') },
    densidad: { v: n => mat.parroquias[n].km2[mi] ?? 0, col: n => PAL.azul[t][clase(mat.parroquias[n].km2[mi] ?? 0, C_DENS)], et: n => fmt(mat.parroquias[n].km2[mi], mat.parroquias[n].km2[mi] < 1 ? 2 : 1), txt: n => fmt(mat.parroquias[n].km2[mi], mat.parroquias[n].km2[mi] < 1 ? 2 : 1) + ' /km²',
      info: n => <><b className="lmi-t">{nom(n)}</b><div className="lmi-f"><b>{fmt(mat.parroquias[n].suma[mi])}</b> delitos en los 12 meses hasta {mesTxt(meses[mi])} · {fmt(mat.parroquias[n].km2[mi], 2)} por km² ({fmt(area[n], 1)} km²){futuro ? ' · pronóstico' : ''}</div></>,
      ley: leyendaSec(C_DENS, PAL.azul[t], v => fmt(v, v < 1 ? 1 : 0), ' /km²') },
    cambio: { v: n => (camb[n]['2025'] < 5 || ruido(camb[n]) ? 0 : camb[n].cambio_2025_2029_pct), col: n => colCambio(camb[n], oscuro), et: n => txtCambio(camb[n]), txt: n => txtCambio(camb[n]),
      info: n => infoCambio(camb[n]), ley: leyCambio(oscuro) },
    abigeato: { v: n => abig[n] || 0, col: n => PAL.tierra[t][clase(abig[n] || 0, C_ABIG)], et: n => fmt(abig[n] || 0), txt: n => fmt(abig[n] || 0) + ' casos',
      info: n => <><b className="lmi-t">{nom(n)}</b><div className="lmi-f"><b>{fmt(abig[n] || 0)}</b> casos de abigeato (2021–2026){D.abigeato['Por parroquia'].find(r => r.parroquia_corta === n) ? ` · ${fmt(D.abigeato['Por parroquia'].find(r => r.parroquia_corta === n).pct, 1)} % del cantón` : ''}</div></>,
      ley: leyendaSec(C_ABIG, PAL.tierra[t], v => fmt(v), ' casos') },
  }[capa];
  const info = CAPAS.find(c => c.k === capa);
  const ranking = D.geo.map(g => g.nom).sort((a, b) => C.v(b) - C.v(a));
  const conSemana = capa === 'estado' || capa === 'prob';

  return (
    <>
      <section className="hero chico">
        <h1>Mapas del cantón Riobamba</h1>
        <p className="lead">Elige qué quieres ver. Todas las capas usan las mismas 12 parroquias; toca una para ver su detalle.</p>
      </section>
      <div className="capas" role="tablist" aria-label="Capa del mapa">
        {CAPAS.map(c => <button key={c.k} role="tab" aria-selected={capa === c.k} className={capa === c.k ? 'on' : ''} onClick={() => setCapa(c.k)}>{c.t}</button>)}
      </div>

      <section className="panel mapas-g">
        <div>
          <div className="mapa-cab">
            <p className="nota">{info.d}</p>
            {conSemana && <Selector semanas={semanas} sem={sw.h} setSem={setSem} />}
            {capa === 'densidad' && (
              <div className="tiempo">
                <button className="btn-play" onClick={() => { if (!play && mi >= meses.length - 1) setMi(11); setPlay(!play); }} aria-label={play ? 'Pausar' : 'Reproducir de 2022 a 2029'}>
                  {play ? <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path d="M7 5h4v14H7zm6 0h4v14h-4z" fill="currentColor" /></svg> : <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path d="M8 5v14l11-7z" fill="currentColor" /></svg>}
                </button>
                <div className="tiempo-r">
                  <div className="tiempo-t"><b>{mesLargo(meses[mi])}</b><span className={`tag-t ${futuro ? 'fut' : ''}`}>{futuro ? 'pronóstico' : 'dato real'}</span></div>
                  <input type="range" min="11" max={meses.length - 1} value={mi} onChange={e => { setPlay(false); setMi(+e.target.value); }} aria-label="Mes" />
                  <div className="lim"><span>{mesTxt(meses[11])}</span><span>{mesTxt(meses[meses.length - 1])}</span></div>
                </div>
              </div>
            )}
          </div>
          <MapaLeaflet geo={D.geo} sel={sel} atenuar={false} onSel={verParroquia} oscuro={oscuro} alto={560} titulo={`Mapa: ${info.t}`}
            color={C.col} etiqueta={C.et} info={C.info} leyenda={C.ley}>
            <span><i className="d-foco" />Foco</span>
          </MapaLeaflet>
        </div>
        <aside className="mapas-l" aria-label="Ranking de parroquias">
          <h2>De mayor a menor</h2>
          <ol>
            {ranking.map(n => (
              <li key={n}><button onClick={() => verParroquia(n)} onPointerEnter={() => setSel(n)} onPointerLeave={() => setSel(null)} onFocus={() => setSel(n)} onBlur={() => setSel(null)}>
                <i style={{ background: C.col(n) }} /><span>{nom(n)}{esFoco(n) && <Foco />}</span><b>{C.txt(n)}</b>
              </button></li>))}
          </ol>
        </aside>
      </section>
    </>
  );
}

/* ---------- 4. Cómo se calcula ---------- */
function Metodo({ D, pron, sw, esc, setEsc, umbral, setUmbral }) {
  const E = D.esc, fila = n => (E?.comparacion.find(r => r.escenario === n)) || {};
  const m = D.resumen[0], b = D.resumen.find(r => r.modelo === 'Base: semana anterior');
  const cod1 = D.codigo.find(c => c.codigo_coip === 1);
  const ab = D.abigeato, abTot = ab['Por anio'].reduce((s, r) => s + r.casos, 0);
  const alertas = pron.filter(p => p.alerta !== 'Normal').length;
  return (
    <>
      <section className="hero">
        <h1>Cómo se calcula cada número</h1>
        <p className="lead">Todo sale de los scripts de R del proyecto (01 a 13), con los registros del ECU 911 de julio de 2021 a septiembre de 2026. Aquí está, en orden, lo que hay que saber para leer el tablero con criterio.</p>
      </section>

      <section className="panel">
        <h2>Qué se cuenta como delito</h2>
        <p className="nota">El ECU 911 registra llamadas de todo tipo. Solo el <b>{fmt(cod1.pct, 1)} %</b> ({fmt(cod1.registros)} registros) son delitos explícitos según el catálogo COIP; eso es lo que se predice.</p>
        <Barras fmtv={v => fmt(v, 1) + ' %'} items={D.codigo.slice().sort((a, b) => b.pct - a.pct).map(c => ({ n: c.significado, v: c.pct, c: c.codigo_coip === 1 ? 'var(--acc)' : 'var(--neutral)' }))} />
      </section>

      {E && (
        <section className="panel">
          <h2>Probar otra definición de delito</h2>
          <p className="nota">El equipo propone sumar otros tipos que el COIP sí nombra. Son un borrador: deben validarlos Sonia y los tutores. Al elegir una, todo el tablero se recalcula.</p>
          <div className="escs" role="radiogroup" aria-label="Definición de delito">
            {ESC_INFO.map(x => { const f = fila(x.fila); return (
              <button key={x.k} role="radio" aria-checked={esc === x.k} className={esc === x.k ? 'on' : ''} onClick={() => setEsc(x.k)}>
                <b>{x.t}</b><span>{x.d}</span>
                <small>{fmt(f['Delitos (registros)'])} delitos · error en Riobamba {fmt(f['Error relativo Riobamba %'], 1)} %</small>
              </button>); })}
          </div>
        </section>
      )}

      <section className="panel">
        <h2>¿Cuándo se marca una alerta?</h2>
        <p className="nota">Se compara el pronóstico con el promedio de las últimas 52 semanas. Hay <b>alerta</b> cuando lo supera en el porcentaje elegido <b>y</b> la diferencia es mayor que la variación normal (así una parroquia con 0,2 delitos no salta por 0,1 más). <b>Atención</b> usa la mitad de ese porcentaje.</p>
        <div className="umbral">
          <label htmlFor="umbral">Alerta cuando supera lo habitual en <b>{umbral} %</b></label>
          <input id="umbral" type="range" min="5" max="60" step="5" value={umbral} onChange={e => setUmbral(+e.target.value)} />
          <div className="lim"><span>Más sensible</span><span>Menos sensible</span></div>
          <p className="nota">Con este valor hay <b>{alertas}</b> {alertas === 1 ? 'parroquia-semana' : 'parroquias-semana'} en atención o alerta en las 12 semanas pronosticadas. El valor del proyecto es 25 %.</p>
        </div>
      </section>

      <section className="panel">
        <h2>¿Se puede confiar en el pronóstico?</h2>
        <p className="nota">Se guardó el último año (52 semanas) como prueba y se comparó lo predicho con lo que pasó. Ningún modelo acierta todo: un delito más o menos en una semana depende de circunstancias que no quedan en los datos.</p>
        <div className="cifras">
          <div><span>Error medio por parroquia y semana</span><b>{fmt(m['Todas las parroquias'], 2)}</b></div>
          <div><span>Mejora frente a «igual que la semana pasada»</span><b>{fmt((1 - m['Todas las parroquias'] / b['Todas las parroquias']) * 100)} %</b></div>
          <div><span>Error en Riobamba (urbana)</span><b>{fmt(m['Urbana (Riobamba)'], 1)} <small>≈ 12 %</small></b></div>
          <div><span>Error en Cubijíes / Flores</span><b>{fmt(m['Cubijíes'], 2)} / {fmt(m['Flores'], 2)}</b></div>
        </div>
        <details className="mas">
          <summary>Ver los {D.resumen.length} modelos comparados</summary>
          <p className="nota">Error medio (MAE) en todas las parroquias; menor es mejor. Verde: el elegido. Gris: comparaciones simples.</p>
          <Barras fmtv={v => fmt(v, 2)} items={D.resumen.map((r, i) => ({ n: r.modelo, v: r['Todas las parroquias'], c: i === 0 ? 'var(--ok)' : r.modelo.startsWith('Base') ? 'var(--neutral)' : 'var(--acc-mid)' }))} />
        </details>
      </section>

      <section className="panel">
        <h2>Abigeato (robo de ganado)</h2>
        <p className="nota">{fmt(abTot)} casos registrados entre 2021 y 2026; el {fmt(100 - ab['Por parroquia'].find(r => r.parroquia_corta === 'RIOBAMBA').pct)} % fuera de la zona urbana. 2021 y 2026 son años incompletos.</p>
        <div className="dos">
          <div><h3>Por año</h3><Columnas h={200} label="Abigeato por año" items={ab['Por anio'].map(r => ({ n: String(r.anio), v: r.casos }))} /></div>
          <div><h3>Dónde ocurre</h3><Barras items={ab['Por parroquia'].slice(0, 8).map(r => ({ n: nom(r.parroquia_corta), v: r.casos }))} /></div>
        </div>
      </section>

      <section className="panel prosa">
        <h2>Método y límites</h2>
        <ol>
          <li>Se unen y limpian los archivos mensuales del ECU 911 (fechas, duplicados, parroquias) y se filtra el cantón Riobamba.</li>
          <li>Cada registro se clasifica con el catálogo COIP; se predice el código 1 (delito explícito) por parroquia y semana.</li>
          <li>Riobamba urbana usa random forest; las parroquias rurales, binomial negativa. Cada zona usa el modelo que menos se equivocó.</li>
          <li>La tendencia a 2029 usa el método que mejor acertó en una prueba con los últimos 24 meses.</li>
        </ol>
        <ul>
          <li>El ECU 911 registra llamadas, no sentencias.</li>
          <li>La ubicación llega solo a nivel de parroquia: no hay coordenadas de cada incidente.</li>
          <li>Flores y Cubijíes tienen muy pocos casos (91 % y 64 % de sus semanas sin ninguno): se informa una probabilidad, no un número exacto.</li>
          <li>Febrero de 2023 no trae el tipo de incidente y se estimó con los meses vecinos.</li>
        </ul>
        <div className="pie-logos">
          <img src="/logo-stanford.png" alt="Instituto Superior Universitario Stanford" width="72" height="72" loading="lazy" />
          <img src="/logo-unach-cdia.png" alt="UNACH · Ingeniería en Ciencia de Datos e Inteligencia Artificial" width="72" height="72" loading="lazy" />
          <p><b>Instituto Superior Universitario Stanford</b><br />Universidad Nacional de Chimborazo · Ingeniería en Ciencia de Datos e Inteligencia Artificial</p>
        </div>
        <p className="nota">Proyecto STANFORD · UNACH · tutores Mg. Ronny Pomboza y Mg. Johanna Moyano.</p>
      </section>
    </>
  );
}
