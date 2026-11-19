export const fmt = (x, d = 0) =>
  x == null || Number.isNaN(x) ? '–' : Number(x).toLocaleString('es-EC', { minimumFractionDigits: d, maximumFractionDigits: d });
/* Pocos delitos → un decimal; muchos → entero */
export const fmtN = x => fmt(x, x != null && Math.abs(x) < 10 ? 1 : 0);

const NOMBRES = { CUBIJIES: 'Cubijíes', LICAN: 'Licán', PUNGALA: 'Pungalá', PUNIN: 'Punín', 'SAN JUAN': 'San Juan', 'SAN LUIS': 'San Luis', QUIMIAG: 'Quimiag', LICTO: 'Licto', CALPI: 'Calpi', CACHA: 'Cacha', FLORES: 'Flores', RIOBAMBA: 'Riobamba' };
export const nom = s => NOMBRES[s] || s;
export const FOCO = ['CUBIJIES', 'FLORES'];
export const esFoco = s => FOCO.includes(s);

/* Estado de alerta: el modelo (R, script 10) entrega Normal / Media / Alta. En pantalla se dice Normal / Atención / Alerta. */
export const ESTADO = {
  Normal: { t: 'Normal', frase: 'dentro de lo habitual', v: 'var(--ok)', bg: 'var(--ok-bg)' },
  Media: { t: 'Atención', frase: 'algo por encima de lo habitual', v: 'var(--warn)', bg: 'var(--warn-bg)' },
  Alta: { t: 'Alerta', frase: 'bastante por encima de lo habitual', v: 'var(--bad)', bg: 'var(--bad-bg)' },
};

export const MN = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
export const MESES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
export const mesTxt = s => { const [a, b] = s.split('-'); return MN[b - 1] + ' ' + a; };
export const mesLargo = s => { const [a, b] = s.split('-'); return MESES[b - 1] + ' de ' + a; };

const DIA = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
const suma = (iso, n) => { const d = new Date(iso + 'T12:00:00'); d.setDate(d.getDate() + n); return d; };
/* Semana de lunes a domingo a partir de su fecha de inicio (YYYY-MM-DD) */
export function semana(iso) {
  const a = suma(iso, 0), b = suma(iso, 6);
  const corto = d => `${d.getDate()} ${MN[d.getMonth()]}`;
  const largo = d => `${DIA[d.getDay()]} ${d.getDate()} de ${MESES[d.getMonth()]}`;
  return { corto: `${corto(a)} – ${corto(b)}`, desde: corto(a), largo: `del ${largo(a)} al ${largo(b)}`, anio: b.getFullYear(), ini: a, fin: b };
}

/* Probabilidad de al menos un delito, en palabras */
export const probTxt = p => (p < 20 ? 'poco probable' : p < 60 ? 'posible' : p < 90 ? 'probable' : 'casi seguro');

/* ¿El cambio 2025→2029 cabe dentro de la variación normal? (≈ ±2·√n de una cuenta de Poisson) */
export const ruido = c => Math.abs(c['2029'] - c['2025']) < 2 * Math.sqrt(Math.max(c['2025'], 1));

/* Paleta categórica para comparar parroquias (validada para daltonismo en orden) */
export const PAL = ['#2a6f97', '#c8553d', '#4f7d3a', '#b5838d', '#7a5c99', '#d4a017', '#3d8a8a', '#8d6e4f', '#5c6b7a', '#b04a6f', '#2f8f5b', '#9a7b1f'];
