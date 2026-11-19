'use client';
import { useEffect, useRef, useState } from 'react';
import { nom } from '../lib/util';

/* Mapas base gratuitos y sin clave (Esri): gris claro / gris oscuro con nombres de lugares, y satélite con nombres */
const ESRI = s => `https://server.arcgisonline.com/ArcGIS/rest/services/${s}/MapServer/tile/{z}/{y}/{x}`;
const TILES = {
  claro: [ESRI('Canvas/World_Light_Gray_Base'), ESRI('Canvas/World_Light_Gray_Reference'), 'Mapa © Esri, HERE, Garmin, © OpenStreetMap'],
  oscuro: [ESRI('Canvas/World_Dark_Gray_Base'), ESRI('Canvas/World_Dark_Gray_Reference'), 'Mapa © Esri, HERE, Garmin, © OpenStreetMap'],
  sat: [ESRI('World_Imagery'), ESRI('Reference/World_Boundaries_and_Places'), 'Imágenes © Esri, Maxar, Earthstar Geographics'],
};

/* Mapa de las 12 parroquias sobre un mapa real (Leaflet).
   color(n) → color de relleno · etiqueta(n) → texto bajo el nombre · info(n) → contenido del recuadro al pasar el cursor
   sel → parroquia resaltada · enfocar → acercar a la parroquia elegida · leyenda → [[texto, color], …] */
export default function MapaLeaflet({ geo, color, etiqueta, info, sel, onSel, oscuro = false, alto = 460, enfocar = false, atenuar = true, nombres = true, leyenda, titulo, children }) {
  const el = useRef(null), R = useRef({});
  const [listo, setListo] = useState(false);
  const [sat, setSat] = useState(false);
  const [hov, setHov] = useState(null);
  const [falla, setFalla] = useState(false);
  Object.assign(R.current, { onSel, enfocar, sel });

  /* crear el mapa una sola vez */
  useEffect(() => {
    let vivo = true, map, ro;
    import('leaflet').then(({ default: L }) => {
      if (!vivo || !el.current) return;
      map = L.map(el.current, { zoomControl: false, scrollWheelZoom: false, zoomSnap: 0.25, minZoom: 8, maxZoom: 17, dragging: !L.Browser.mobile, tap: false });
      L.control.zoom({ position: 'topright', zoomInTitle: 'Acercar', zoomOutTitle: 'Alejar' }).addTo(map);
      map.attributionControl.setPrefix('<a href="https://leafletjs.com">Leaflet</a>');
      const fc = { type: 'FeatureCollection', features: geo.map(g => ({ type: 'Feature', properties: { nom: g.nom, foco: g.foco, area: g.area }, geometry: { type: 'MultiPolygon', coordinates: g.poly } })) };
      const capa = L.geoJSON(fc, {
        onEachFeature: (f, l) => {
          l.bindTooltip('', { permanent: true, direction: 'center', className: f.properties.area < 35 ? 'lm-et lm-et-chica' : 'lm-et', interactive: false, opacity: 1 });
          l.on('mouseover', () => setHov(f.properties.nom));
          l.on('mouseout', () => setHov(null));
          l.on('click', () => R.current.onSel && R.current.onSel(f.properties.nom));
        },
      }).addTo(map);
      /* encuadre: la parroquia elegida (si el mapa debe enfocarla) o todo el cantón */
      const ajustar = () => {
        const { enfocar: e, sel: s } = R.current, l = e && s && capa.getLayers().find(x => x.feature.properties.nom === s);
        map.fitBounds(l ? l.getBounds() : capa.getBounds(), { padding: l ? [70, 70] : [12, 12], maxZoom: 12, animate: false });
      };
      ajustar();
      let movido = false;
      map.on('dragstart', () => { movido = true; });
      el.current.addEventListener('wheel', () => { movido = true; }, { passive: true });
      map.zoomControl?.getContainer?.().addEventListener('click', () => { movido = true; });
      ro = new ResizeObserver(() => { map.invalidateSize(); if (!movido) ajustar(); });
      ro.observe(el.current);
      Object.assign(R.current, { L, map, capa });      setListo(true);
    });
    return () => { vivo = false; if (ro) ro.disconnect(); if (map) map.remove(); };
  }, [geo]);

  /* pintar parroquias */
  useEffect(() => {
    if (!listo) return;
    R.current.capa.eachLayer(l => {
      const { nom: n, foco } = l.feature.properties, s = sel === n, h = hov === n;
      l.setStyle({
        fillColor: color(n), fillOpacity: sel && !s && atenuar ? 0.3 : sat ? 0.6 : 0.74,
        color: s || h ? (oscuro ? '#ffffff' : '#111820') : foco ? (oscuro ? '#e8ecef' : '#1d2733') : (oscuro ? '#12171d' : '#ffffff'),
        weight: s ? 3.5 : h ? 2.6 : foco ? 2.2 : 1.3, dashArray: foco && !s && !h ? '6 4' : null, opacity: 1,
      });
      if (s || h) l.bringToFront();
      const e = etiqueta ? etiqueta(n) : '';
      l.setTooltipContent(nombres ? `<b>${nom(n)}</b>${e !== '' && e != null ? `<span>${e}</span>` : ''}` : e != null ? `<span>${e}</span>` : '');
    });
  });

  /* mapa base */
  useEffect(() => {
    if (!listo) return;
    const { L, map } = R.current;
    if (!map.getPane('nombres')) { const p = map.createPane('nombres'); p.style.zIndex = 450; p.style.pointerEvents = 'none'; }
    [R.current.base, R.current.ref].forEach(c => c && map.removeLayer(c));
    const [u, ref, a] = TILES[sat ? 'sat' : oscuro ? 'oscuro' : 'claro'];
    let errores = 0;
    R.current.base = L.tileLayer(u, { attribution: a, maxZoom: 17, maxNativeZoom: 16 }).addTo(map);
    R.current.ref = L.tileLayer(ref, { pane: 'nombres', maxZoom: 17, maxNativeZoom: 16, opacity: 0.6 }).addTo(map);
    R.current.base.on('tileerror', () => { errores += 1; if (errores > 8) setFalla(true); });
    R.current.base.on('load', () => setFalla(false));
    R.current.base.bringToBack();
  }, [listo, sat, oscuro]);

  /* acercar a la parroquia elegida */
  useEffect(() => {
    if (!listo || !enfocar) return;
    const { map, capa } = R.current;
    const l = sel && capa.getLayers().find(x => x.feature.properties.nom === sel);
    map.flyToBounds(l ? l.getBounds() : capa.getBounds(), { padding: l ? [70, 70] : [12, 12], maxZoom: 12, duration: 0.7 });
  }, [listo, sel, enfocar]);

  const verTodo = () => R.current.map && R.current.map.flyToBounds(R.current.capa.getBounds(), { padding: [12, 12], duration: 0.6 });

  return (
    <div className="lmapa" style={{ height: alto }}>
      <div ref={el} className="lmapa-c" role="application" aria-label={titulo || 'Mapa de parroquias del cantón Riobamba'} />
      {!listo && <div className="lm-carga">Cargando mapa…</div>}
      <div className="lm-ctl">
        <div className="seg" role="group" aria-label="Fondo del mapa">
          <button className={!sat ? 'on' : ''} aria-pressed={!sat} onClick={() => setSat(false)}>Mapa</button>
          <button className={sat ? 'on' : ''} aria-pressed={sat} onClick={() => setSat(true)}>Satélite</button>
        </div>
        <button className="lm-todo" onClick={verTodo}>Ver todo</button>
      </div>
      {info && (
        <div className={`lm-info ${hov ? 'on' : ''}`} aria-live="polite">
          {hov ? info(hov) : <span className="mut">Pasa el cursor o toca una parroquia</span>}
        </div>
      )}
      {(leyenda || children) && (
        <div className="lm-ley">
          {leyenda && leyenda.map(([t, c]) => <span key={t}><i style={{ background: c }} />{t}</span>)}
          {children}
        </div>
      )}
      {falla && <div className="lm-falla">El mapa base no cargó (sin internet). Las parroquias y sus colores siguen siendo válidos.</div>}
    </div>
  );
}
