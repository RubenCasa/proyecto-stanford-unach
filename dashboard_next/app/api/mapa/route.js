import L from '../../../lib/logica';
import D from '../../../data/data.json';

export const dynamic = 'force-dynamic';

export async function GET(request) {
  const q = Object.fromEntries(new URL(request.url).searchParams);
  const r = L.mapa(D, q);
  return Response.json(r, {
    status: r && r.error ? 404 : 200,
    headers: { 'Cache-Control': 'public, s-maxage=300, stale-while-revalidate=3600' },
  });
}
