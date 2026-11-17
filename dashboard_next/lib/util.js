export const fmt = (x, d = 0) =>
  x == null || Number.isNaN(x) ? '–' : Number(x).toLocaleString('es-EC', { minimumFractionDigits: d, maximumFractionDigits: d });
const NOMBRES = { CUBIJIES: 'Cubijíes', LICAN: 'Licán', PUNGALA: 'Pungalá', PUNIN: 'Punín', 'SAN JUAN': 'San Juan', 'SAN LUIS': 'San Luis', QUIMIAG: 'Quimiag', LICTO: 'Licto', CALPI: 'Calpi', CACHA: 'Cacha', FLORES: 'Flores', RIOBAMBA: 'Riobamba' };
export const nom = s => NOMBRES[s] || s;
export const FOCO = ['FLORES', 'CUBIJIES'];
export const COL = { Normal: '#8bc9a3', Media: '#f0a829', Alta: '#e0533a' };
export const MN = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
export const mesTxt = s => { const [a, b] = s.split('-'); return MN[b - 1] + ' ' + a; };
export const PAL = ['#1f6fb2', '#e0533a', '#3f9d6b', '#f0a829', '#7d5bbe', '#2bb3c0', '#c0392b', '#8e7f3a', '#5a6b7b', '#d2691e', '#16a085', '#b0507a'];

const MES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
const DIA = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
const suma = (iso, n) => { const d = new Date(iso + 'T12:00:00'); d.setDate(d.getDate() + n); return d; };
/* Semana de lunes a domingo a partir de su fecha de inicio (YYYY-MM-DD) */
export function semana(iso) {
  const a = suma(iso, 0), b = suma(iso, 6);
  const corto = d => `${d.getDate()} ${MES[d.getMonth()].slice(0, 3)}`;
  const largo = d => `${DIA[d.getDay()]} ${d.getDate()} de ${MES[d.getMonth()]}`;
  return { corto: `${corto(a)} – ${corto(b)}`, largo: `del ${largo(a)} al ${largo(b)}`, anio: b.getFullYear(), ini: a, fin: b };
}
/* Carita y frase según las alertas de una semana */
export function carita(filas) {
  const altas = filas.filter(p => p.alerta === 'Alta'), med = filas.filter(p => p.alerta === 'Media');
  const nombres = l => l.map(p => nom(p.parroquia_corta)).join(' y ');
  if (altas.length) return { e: '😟', t: `Alerta en ${nombres(altas)}`, c: '#e0533a' };
  if (med.length) return { e: '😐', t: `Atención en ${nombres(med)}`, c: '#d08a00' };
  return { e: '🙂', t: 'Todo tranquilo', c: '#3f9d6b' };
}
