/* Escalas de color de los mapas (hex: Leaflet no entiende variables CSS). Una versión para tema claro y otra para oscuro. */
export const PAL = {
  estado: {
    claro: { Normal: '#9fceae', Media: '#f2c25c', Alta: '#e0664c' },
    oscuro: { Normal: '#3d7a56', Media: '#b9862a', Alta: '#c9543b' },
  },
  azul: { claro: ['#e1edf7', '#a9cbe6', '#69a4d1', '#2f78b7', '#0d4a86'], oscuro: ['#22384b', '#2c5577', '#3f77a6', '#62a0d4', '#a6cdee'] },
  tierra: { claro: ['#f7ead0', '#edcb8d', '#dca253', '#b9742b', '#7d4914'], oscuro: ['#3a2f20', '#664a24', '#946a2e', '#c4914a', '#e8bf7f'] },
  cambio: {
    claro: { subeMucho: '#c8553d', sube: '#eda58f', estable: '#cbc5b8', baja: '#93c2e1', bajaMucho: '#2a6f97' },
    oscuro: { subeMucho: '#d9644b', sube: '#8f4a3a', estable: '#4d5660', baja: '#2f5f80', bajaMucho: '#6fb0dd' },
  },
};

/* Clase de una escala por cortes: cortes = [c1, c2, c3, c4] → 5 clases */
export const clase = (v, cortes) => { let i = 0; while (i < cortes.length && v > cortes[i]) i++; return i; };

/* Leyenda de una escala secuencial: [['< c1', color], …] */
export function leyendaSec(cortes, colores, fmtc = String, suf = '') {
  return colores.map((c, i) => [
    i === 0 ? `hasta ${fmtc(cortes[0])}${suf}` : i === cortes.length ? `más de ${fmtc(cortes[i - 1])}${suf}` : `${fmtc(cortes[i - 1])}–${fmtc(cortes[i])}${suf}`, c]);
}
