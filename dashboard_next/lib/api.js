import LOG from './logica';

/* Pide el dato a /api/<ep>; si el servidor no responde, calcula lo mismo en el navegador. */
export async function api(ep, q = {}, D) {
  try {
    const r = await fetch(`/api/${ep}?${new URLSearchParams(q)}`);
    if (r.ok) return { data: await r.json(), fuente: 'API' };
  } catch (e) { /* sin red: se usa el respaldo local */ }
  return { data: LOG[ep](D, q), fuente: 'local' };
}
