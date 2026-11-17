import Dashboard from '../components/Dashboard';
import L from '../lib/logica';
import D from '../data/data.json';

export default function Page() {
  // El servidor entrega los datos y las alertas iniciales ya calculadas (umbral 25 %).
  const pron = L.pronostico(D, { umbral: 25 }).filas;
  return <Dashboard datos={D} pronInicial={pron} />;
}
