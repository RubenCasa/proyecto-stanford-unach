export const fmt = (x, d = 0) =>
  x == null || Number.isNaN(x) ? '–' : Number(x).toLocaleString('es-EC', { minimumFractionDigits: d, maximumFractionDigits: d });
const NOMBRES = { CUBIJIES: 'Cubijíes', LICAN: 'Licán', PUNGALA: 'Pungalá', PUNIN: 'Punín', 'SAN JUAN': 'San Juan', 'SAN LUIS': 'San Luis', QUIMIAG: 'Quimiag', LICTO: 'Licto', CALPI: 'Calpi', CACHA: 'Cacha', FLORES: 'Flores', RIOBAMBA: 'Riobamba' };
export const nom = s => NOMBRES[s] || s;
export const FOCO = ['FLORES', 'CUBIJIES'];
export const COL = { Normal: '#8bc9a3', Media: '#f0a829', Alta: '#e0533a' };
export const MN = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
export const mesTxt = s => { const [a, b] = s.split('-'); return MN[b - 1] + ' ' + a; };
export const PAL = ['#1f6fb2', '#e0533a', '#3f9d6b', '#f0a829', '#7d5bbe', '#2bb3c0', '#c0392b', '#8e7f3a', '#5a6b7b', '#d2691e', '#16a085', '#b0507a'];
