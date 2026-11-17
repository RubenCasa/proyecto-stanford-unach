'use client';
import { useEffect, useMemo, useRef, useState } from 'react';
import { LineChart } from './Charts';
import { COL, FOCO, fmt, nom, mesTxt } from '../lib/util';
const FOCO_SET = new Set(FOCO);

const escala = v => (v > 50 ? '#0b3d6e' : v > 5 ? '#2f78b7' : v > 1 ? '#74b3dc' : v > 0.1 ? '#bcdcef' : '#e9f3f9');
const ESRI = 'Tiles © Esri';
const TILES = {
  calles: ['https://tile.openstreetmap.org/{z}/{x}/{y}.png', { attribution: '© OpenStreetMap', maxZoom: 19 }],
  claro: ['https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}', { attribution: ESRI, maxZoom: 16 }],
  oscuro: ['https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}', { attribution: ESRI, maxZoom: 16 }],
  sat: ['https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', { attribution: 'Imágenes © Esri', maxZoom: 18 }],
};
const BASES = [['calles', 'Calles'], ['claro', 'Claro'], ['oscuro', 'Oscuro'], ['sat', 'Satélite']];
const DESC = {
  tiempo: 'Cuántos delitos hubo en cada parroquia en los 12 meses que terminan en la fecha elegida. Más oscuro = más delitos por km².',
  alerta: 'Semáforo de esta semana: verde = normal, amarillo = atención, rojo = alerta (se espera más de lo habitual).',
  cambio: 'Cómo cambiarán los delitos de 2025 a 2029. Rojo = sube, azul = baja.',
  total: 'Total de delitos registrados en 2025 en cada parroquia.',
};
const riesgoTxt = p => (p < 20 ? ['poco probable', '#3f9d6b'] : p < 60 ? ['posible', '#d08a00'] : ['muy probable', '#e0533a']);

export default function MapaVivo({ datos: D, pron1, mat, sel, onSel, onTendencia, dark }) {
  const el = useRef(null), R = useRef({});          // R: leaflet, mapa, capa, base
  const [listo, setListo] = useState(false);
  const [met, setMet] = useState('tiempo');
  const [base, setBase] = useState('calles');
  const [aviso, setAviso] = useState('');
  const [ayuda, setAyuda] = useState(true);
  const meses = mat.meses, [mi, setMi] = useState(meses.indexOf('2025-12'));
  const [play, setPlay] = useState(false);
  const camb = D.cambio;

  const METS = useMemo(() => ({
    tiempo: { t: '📅 En el tiempo', d: n => ({ suma: mat.parroquias[n].suma[mi], km2: mat.parroquias[n].km2[mi], fc: mat.parroquias[n].fc[mi] }),
      col: d => escala(d.km2), lbl: d => fmt(d.suma), ord: d => d.km2, leg: [['> 50 / km²', '#0b3d6e'], ['5–50', '#2f78b7'], ['1–5', '#74b3dc'], ['0,1–1', '#bcdcef'], ['< 0,1', '#e9f3f9']] },
    alerta: { t: '🚦 Alertas', d: n => pron1.find(p => p.parroquia_corta === n), col: p => COL[p.alerta], lbl: p => p.alerta, ord: p => p.indice, leg: [['Normal', COL.Normal], ['Media', COL.Media], ['Alta', COL.Alta]] },
    cambio: { t: '🔮 Hacia 2029', d: n => camb.find(c => c.parroquia_corta === n),
      col: c => { const v = c.cambio_2025_2029_pct; return v > 10 ? '#e0533a' : v > 0 ? '#f3a58f' : v > -10 ? '#a9d3e8' : '#2f86b8'; },
      lbl: c => (c.cambio_2025_2029_pct > 0 ? '+' : '') + fmt(c.cambio_2025_2029_pct, 0) + ' %', ord: c => c.cambio_2025_2029_pct, leg: [['Sube > 10 %', '#e0533a'], ['Sube hasta 10 %', '#f3a58f'], ['Baja hasta 10 %', '#a9d3e8'], ['Baja > 10 %', '#2f86b8']] },
    total: { t: '📊 Total 2025', d: n => camb.find(c => c.parroquia_corta === n),
      col: c => { const v = c['2025']; return v > 1000 ? '#0b3d6e' : v > 50 ? '#2f78b7' : v > 10 ? '#74b3dc' : '#bcdcef'; },
      lbl: c => fmt(c['2025']), ord: c => c['2025'], leg: [['> 1.000', '#0b3d6e'], ['51–1.000', '#2f78b7'], ['11–50', '#74b3dc'], ['≤ 10', '#bcdcef']] },
  }), [mat, mi, pron1, camb]);

  /* crear el mapa una sola vez */
  useEffect(() => {
    let vivo = true, map;
    (async () => {
      const L = (await import('leaflet')).default;
      if (!vivo || !el.current) return;
      map = L.map(el.current, { zoomControl: false, minZoom: 9, maxZoom: 17, zoomSnap: 0.25 }).setView([-1.67, -78.65], 10);
      L.control.zoom({ position: 'bottomright' }).addTo(map);
      const fc = { type: 'FeatureCollection', features: D.geo.map(g => ({ type: 'Feature', properties: { nom: g.nom, foco: g.foco }, geometry: { type: 'MultiPolygon', coordinates: g.poly } })) };
      const capa = L.geoJSON(fc, { style: () => ({ weight: 1.5, color: '#fff', fillOpacity: 0.7 }) }).addTo(map);
      capa.eachLayer(l => {
        const g = l.feature.properties;
        l.bindTooltip('', { permanent: true, direction: 'center', className: 'lbl' });
        l.on('mouseover', () => { l.setStyle({ weight: 3, color: '#0b1b2b' }); l.bringToFront(); });
        l.on('mouseout', () => R.current.estilo && R.current.estilo(l));
        l.on('click', () => R.current.click && R.current.click(g.nom));
      });
      map.fitBounds(capa.getBounds(), { padding: [30, 30] });
      R.current = { ...R.current, L, map, capa };
      setListo(true);
    })();
    return () => { vivo = false; if (map) map.remove(); R.current = {}; };
  }, [D]);

  /* repintar al cambiar capa, mes, selección o alertas */
  useEffect(() => {
    if (!listo) return;
    const { capa } = R.current, m = METS[met];
    R.current.click = n => onSel(n);
    R.current.estilo = l => {
      const g = l.feature.properties, d = m.d(g.nom);
      l.setStyle({ fillColor: d ? m.col(d) : '#ccc', fillOpacity: sel && sel !== g.nom ? 0.3 : base === 'sat' ? 0.5 : 0.58,
        color: sel === g.nom ? '#e0533a' : g.foco ? '#0b1b2b' : '#fff', weight: sel === g.nom ? 4 : g.foco ? 3 : 1.4, dashArray: g.foco && sel !== g.nom ? '6 4' : null });
      l.setTooltipContent(`${nom(g.nom)}${d ? ` · <b>${m.lbl(d)}</b>` : ''}`);
    };
    capa.eachLayer(R.current.estilo);
  }, [listo, met, METS, sel, onSel, base]);

  /* mapa base */
  useEffect(() => {
    if (!listo) return;
    const { L, map } = R.current;
    if (R.current.baseLayer) map.removeLayer(R.current.baseLayer);
    const [u, o] = TILES[base];
    let fallos = 0;
    R.current.baseLayer = L.tileLayer(u, o).addTo(map);
    R.current.baseLayer.on('tileerror', () => {
      fallos += 1;
      if (fallos === 6 && base !== 'calles') { setAviso('Ese fondo no está disponible ahora; se volvió a «Calles».'); setBase('calles'); setTimeout(() => setAviso(''), 6000); }
    });
    R.current.baseLayer.bringToBack();
  }, [listo, base]);

  /* volar a la parroquia elegida */
  useEffect(() => {
    if (!listo || !sel) return;
    const { map, capa } = R.current, l = capa.getLayers().find(x => x.feature.properties.nom === sel);
    if (l) map.flyToBounds(l.getBounds(), { padding: [60, 60], duration: 0.9, maxZoom: 13 });
  }, [listo, sel]);

  /* tamaño correcto al mostrarse */
  useEffect(() => { if (listo) setTimeout(() => R.current.map.invalidateSize(), 60); }, [listo]);

  /* reproducción */
  useEffect(() => {
    if (!play) return;
    const t = setInterval(() => setMi(v => { if (v >= meses.length - 1) { setPlay(false); return v; } return v + 1; }), 380);
    return () => clearInterval(t);
  }, [play, meses.length]);

  const todo = () => { onSel(null); R.current.map.flyToBounds(R.current.capa.getBounds(), { padding: [30, 30], duration: 0.8 }); };
  const foco = () => { const { L, map, capa } = R.current; map.flyToBounds(L.featureGroup(capa.getLayers().filter(l => l.feature.properties.foco)).getBounds(), { padding: [80, 80], duration: 0.9 }); };

  const m = METS[met];
  const g = sel && D.geo.find(x => x.nom === sel), c = sel && camb.find(x => x.parroquia_corta === sel), p = sel && pron1.find(x => x.parroquia_corta === sel), ser = sel && D.mensual[sel];
  const ult = ser ? ser.mes.map((_, i) => i).filter(i => ser.mes[i] >= '2023-01') : [];
  const ip = ser ? ser.tipo.indexOf('Pronóstico') : 0;
  const ranking = Object.keys(D.mensual).map(n => ({ n, d: m.d(n) })).filter(x => x.d).sort((a, b) => m.ord(b.d) - m.ord(a.d));
  const rt = p ? riesgoTxt(p.prob_al_menos_1)[0] : '', rc = p ? { Normal: '#3f9d6b', Media: '#d08a00', Alta: '#e0533a' }[p.alerta] : '';

  return (
    <div className="mapwrap">
      <div ref={el} className="mapa" />
      <div className="glass pnl-t"><div className="seg">{BASES.map(([k, t]) => <button key={k} className={base === k ? 'on' : ''} onClick={() => setBase(k)}>{t}</button>)}</div></div>
      {aviso && <div className="glass aviso-m">{aviso}</div>}

      <div className="glass pnl-l">
        <h3 style={{ fontSize: 15, marginBottom: 8 }}>1 · Elige qué ver</h3>
        <div className="seg" style={{ display: 'flex', flexWrap: 'wrap' }}>{Object.entries(METS).map(([k, v]) => <button key={k} className={met === k ? 'on' : ''} onClick={() => { setMet(k); if (k !== 'tiempo') setPlay(false); }}>{v.t}</button>)}</div>
        <p className="n" style={{ margin: '8px 0 0' }}>{DESC[met]}</p>
        {met === 'tiempo' && (
          <div style={{ marginTop: 12 }}>
            <div className="row" style={{ marginBottom: 2 }}><button className="btn" onClick={() => { if (!play && mi >= meses.length - 1) setMi(11); setPlay(!play); }}>{play ? '⏸ Pausar' : '▶ Reproducir'}</button><span className="big" style={{ fontSize: 22 }}>{mesTxt(meses[mi])}</span></div>
            <span className="chip">{meses[mi] > '2026-09' ? '🔮 Pronóstico' : '✔ Dato real'}</span>
            <input type="range" min="0" max={meses.length - 1} value={mi} onChange={e => setMi(+e.target.value)} style={{ marginTop: 8 }} />
          </div>)}
        <h3 style={{ fontSize: 15, margin: '14px 0 6px' }}>2 · Toca una parroquia</h3>
        <div className="rank">
          {ranking.map(({ n, d }) => (
            <button key={n} className={sel === n ? 'on' : ''} onClick={() => onSel(n)}>
              <i style={{ background: m.col(d) }} /><span>{nom(n)}{FOCO_SET.has(n) ? ' ★' : ''}</span><b>{m.lbl(d)}</b>
            </button>))}
        </div>
        <div className="row" style={{ margin: '10px 0 0' }}><button className="btn sec" onClick={foco}>★ Flores y Cubijíes</button><button className="btn sec" onClick={todo}>Ver todo</button></div>
      </div>

      <div className="glass pnl-r">
        {!sel ? (<>
          <h3 style={{ fontSize: 16 }}>Cómo usar este mapa</h3>
          <ol className="lista" style={{ margin: '8px 0 0', paddingLeft: 18 }}>
            <li>Elige una <b>capa</b> arriba a la izquierda.</li>
            <li><b>Toca una parroquia</b> en el mapa o en la lista.</li>
            <li>Aquí verás qué tan probable es un delito esta semana y cómo evoluciona.</li>
          </ol>
          <p className="n" style={{ margin: '10px 0 0' }}>Los colores solo comparan parroquias entre sí: son una guía para priorizar, no una certeza. Cambia el fondo (Calles, Claro, Oscuro, Satélite) arriba.</p>
        </>) : (<>
          <div className="row" style={{ justifyContent: 'space-between', margin: 0 }}><h3 style={{ fontSize: 18, margin: 0 }}>{nom(sel)}{g.foco ? ' ★' : ''}</h3><button className="btn sec" style={{ padding: '4px 10px' }} onClick={() => onSel(null)} aria-label="Cerrar">✕</button></div>
          <p className="n" style={{ margin: '2px 0 10px' }}>{fmt(g.area, 1)} km² · {g.foco ? 'Parroquia foco del proyecto' : 'Parroquia'}</p>
          <div className="veredicto" style={{ borderColor: rc }}>
            <div className="mini">ESTA SEMANA</div>
            <div style={{ fontSize: 17, fontWeight: 700 }}>Es {rt} que ocurra un delito</div>
            <div className="n" style={{ margin: '2px 0 0' }}>Probabilidad de al menos uno: <b>{p.prob_al_menos_1} %</b> · Predicción {fmt(p.prediccion, 1)} (rango {fmt(p.rango_bajo, 1)}–{fmt(p.rango_alto, 1)})</div>
            <div style={{ marginTop: 6 }}><span className={`badge b-${p.alerta}`}>Alerta {p.alerta.toLowerCase()}</span></div>
          </div>
          <div className="grid" style={{ gridTemplateColumns: '1fr 1fr 1fr', gap: 8, marginTop: 10 }}>
            <div><div className="mini">2025</div><div className="num" style={{ fontSize: 20 }}>{fmt(c['2025'])}</div></div>
            <div><div className="mini">2029 (pron.)</div><div className="num" style={{ fontSize: 20 }}>{fmt(c['2029'])}</div></div>
            <div><div className="mini">Cambio</div><div className="num" style={{ fontSize: 18, color: c.cambio_2025_2029_pct > 0 ? '#e0533a' : '#2f86b8' }}>{c.cambio_2025_2029_pct > 0 ? '+' : ''}{c.cambio_2025_2029_pct} %</div></div>
          </div>
          <p className="n" style={{ margin: '10px 0 0' }}>Delitos por mes desde 2023 (punteado = pronóstico)</p>
          <LineChart compact h={120} x={ult.map(i => mesTxt(ser.mes[i]))} corte={ult.indexOf(ip)}
            series={[{ n: 'Real', c: '#1f6fb2', y: ult.map(i => (ser.tipo[i] === 'Real' ? ser.inc[i] : null)) }, { n: 'Pronóstico', c: '#e0533a', dash: 1, y: ult.map(i => (i >= ip - 1 ? ser.inc[i] : null)) }]} yfmt={v => fmt(v, v < 10 ? 1 : 0)} />
          <button className="btn" style={{ marginTop: 10, width: '100%' }} onClick={() => onTendencia(sel)}>Ver el futuro hasta 2029 →</button>
        </>)}
      </div>

      {ayuda && !sel && <div className="glass hint" onClick={() => setAyuda(false)}>👆 Toca cualquier parroquia para ver su detalle <span>✕</span></div>}
      <div className="glass pnl-b"><div className="leg" style={{ margin: 0 }}>{m.leg.map(([t, col]) => <span key={t}><i style={{ background: col }} />{t}</span>)}</div></div>
    </div>
  );
}
