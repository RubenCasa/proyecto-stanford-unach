"""Regenera dashboard_next/data/data.json (datos del tablero publicado) a partir de los resultados de R.
Uso (desde la carpeta del proyecto, después de correr los scripts 07b, 10, 12 y 13):
    python scripts/actualizar_dashboard.py
Requiere: pandas, openpyxl. Solo usa resultados agregados por parroquia (sin datos personales)."""
import sqlite3, struct, json, pandas as pd, datetime as dt
import os; U=os.path.join(os.path.dirname(os.path.abspath(__file__)),"..","03_resultados")+os.sep
def x(f,s): return pd.read_excel(U+f,sheet_name=s)
# --- geometría
def wkb_poly(b):
    bo=b[0]; e='<' if bo==1 else '>'
    t=struct.unpack(e+'I',b[1:5])[0]; off=5
    def poly(off):
        nr=struct.unpack(e+'I',b[off:off+4])[0]; off+=4; rings=[]
        for _ in range(nr):
            n=struct.unpack(e+'I',b[off:off+4])[0]; off+=4
            pts=struct.unpack(e+'%dd'%(2*n),b[off:off+16*n]); off+=16*n
            rings.append([[round(pts[i],5),round(pts[i+1],5)] for i in range(0,2*n,2)])
        return rings,off
    if t%1000==3: r,_=poly(off); return [r]
    if t%1000==6:
        n=struct.unpack(e+'I',b[off:off+4])[0]; off+=4; out=[]
        for _ in range(n):
            off+=5; r,off=poly(off); out.append(r)
        return out
c=sqlite3.connect(os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','04_mapas','parroquias_riobamba.gpkg'))
feats=[]
for cod,nom,foco,area,g in c.execute("select cod_parroquia,parroquia_corta,zona_foco,area_km2,geom from parroquias_riobamba"):
    flags=g[3]; envn=[0,32,48,48,64][(flags>>1)&7]; wkb=g[8+envn:]
    # simplificar: quitar puntos (cada 2º) si muy denso
    polys=wkb_poly(wkb)
    def simp(r):
        if len(r)>900: r=r[::max(1,len(r)//700)]+[r[0]]
        return r
    polys=[[simp(r) for r in p] for p in polys]
    feats.append({"cod":cod,"nom":nom,"foco":bool(foco),"area":area,"poly":polys})
# --- pronóstico
pr=x("modelos/10_resultados_modelos.xlsx","Pronosticos")
pr["semana_inicio"]=pr["semana_inicio"].dt.strftime("%Y-%m-%d")
pron=pr.round(2).to_dict("records")
mae=x("modelos/10_resultados_modelos.xlsx","Metricas").round(2).to_dict("records")
res=x("modelos/10_resultados_modelos.xlsx","Resumen MAE").round(2).to_dict("records")
azar=x("modelos/10_resultados_modelos.xlsx","Limite del azar").round(2).to_dict("records")
rv=x("modelos/10_resultados_modelos.xlsx","Reales vs prediccion").round(2).to_dict("records")
var=x("modelos/10_resultados_modelos.xlsx","Variables").round(1)
var=var.sort_values("importancia_rel",ascending=False).groupby("zona").head(8).to_dict("records")
# --- tendencia
m=x("modelos/12_tendencia_2029.xlsx","Mensual")
m["mes"]=m["mes"].dt.strftime("%Y-%m")
m=m.round(1).where(m.notna(),None)
mens={}
for p,g in m.groupby("parroquia_corta"):
    mens[p]={"mes":g["mes"].tolist(),"inc":g["incidentes"].tolist(),"tipo":g["tipo"].tolist(),
             "b80":g["bajo80"].tolist(),"a80":g["alto80"].tolist(),"b95":g["bajo95"].tolist(),"a95":g["alto95"].tolist(),
             "modelo":g["modelo"].dropna().iloc[0] if g["modelo"].notna().any() else None}
cam=x("modelos/12_tendencia_2029.xlsx","Cambio 2025-2029"); cam.columns=[str(c) for c in cam.columns]
cambio=cam.round(1).to_dict("records")
back=x("modelos/12_tendencia_2029.xlsx","Backtest 24 meses").round(2).to_dict("records")
# --- objetivo
cod=x("tablas/07b_objetivo_delictivo.xlsx","Codigo COIP").round(1).to_dict("records")
tipo=x("tablas/07b_objetivo_delictivo.xlsx","Tipo de registro").round(1).to_dict("records")
av=x("tablas/07b_objetivo_delictivo.xlsx","Antes vs ahora").round(2).to_dict("records")
pa=x("tablas/07b_objetivo_delictivo.xlsx","Por año"); pa=pa.round(1).to_dict("records")
ab={s:x("tablas/13_abigeato.xlsx",s).round(2).to_dict("records") for s in ["Por anio","Por mes","Por parroquia","Por dia"]}
# --- escenarios de definición de delito (base de Sonia / ampliado A / ampliado A+B)
R=os.path.join(os.path.dirname(os.path.abspath(__file__)),"..")
def pron_esc(e):
    q=pd.read_excel(os.path.join(R,"_escenarios",e,"modelos","10_resultados_modelos.xlsx"),sheet_name="Pronosticos")
    q["semana_inicio"]=q["semana_inicio"].dt.strftime("%Y-%m-%d"); return q.round(2).to_dict("records")
cmp_=pd.read_excel(os.path.join(R,"05_documentos","Comparacion_escenarios_objetivo.xlsx"))
cmp_=cmp_.set_index("Indicador").T.reset_index().rename(columns={"index":"escenario"})
ter=pd.read_excel(os.path.join(R,"05_documentos","Terminos_por_justificar_ampliar_base.xlsx"),sheet_name="Por justificar")
ter=ter[["Tipo de registro (regla de palabras clave del equipo; no es del ECU 911)","Subtipo (ECU 911)","Registros","Código de Sonia","Nivel de propuesta","Código propuesto por el equipo","Artículo COIP / protocolo que lo justifica","Justificación"]].fillna("")
ter.columns=["tipo","subtipo","registros","sonia","nivel","propuesto","articulo","justificacion"]
import math
def _alta(r,u=25):
    az=math.sqrt(max(r["media_52_semanas"],0.1)); return r["indice"]>=100+u and r["prediccion"]-r["media_52_semanas"]>=az
_n={"Base (Sonia)":sum(_alta(r) for r in pron),"A":sum(_alta(r) for r in pron_esc("A")),"A+B":sum(_alta(r) for r in pron_esc("AB"))}
def _alerta(r,u=25):
    az=math.sqrt(max(r["media_52_semanas"],0.1)); dif=r["prediccion"]-r["media_52_semanas"]
    return (r["indice"]>=100+u and dif>=az) or (r["indice"]>=100+u/2 and dif>=az/2)
_ed=os.path.join(R,"_escenarios","ED","modelos","10_resultados_modelos.xlsx"); _pe={}
if os.path.exists(_ed): _pe["ED"]=pron_esc("ED")
_m={"Base (Sonia)":sum(_alerta(r) for r in pron),"A":sum(_alerta(r) for r in pron_esc("A")),"A+B":sum(_alerta(r) for r in pron_esc("AB"))}
if "ED" in _pe:
    _m["ED"]=sum(_alerta(r) for r in _pe["ED"])
    _mm=pd.read_excel(_ed,sheet_name="Resumen MAE").set_index("modelo"); _e=_mm.loc["Elegido por zona"]
    _q=pd.DataFrame(_pe["ED"]); _l=_q[_q.horizonte==1].set_index("parroquia_corta").media_52_semanas; _t=_q.groupby("parroquia_corta").prediccion.sum()
    _nd=int(pd.read_excel(os.path.join(R,"_escenarios","ED","tablas","07b_objetivo_delictivo.xlsx"),sheet_name="Codigo COIP").set_index("codigo_coip").loc[1,"registros"])
    _row={"escenario":"ED","Delitos (registros)":_nd,"Promedio semanal Riobamba (52 sem)":round(_l["RIOBAMBA"],1),"Error MAE Riobamba":round(_e["Urbana (Riobamba)"],2),
      "Error relativo Riobamba %":round(100*_e["Urbana (Riobamba)"]/_l["RIOBAMBA"],1),"Promedio semanal Cubijíes":round(_l["CUBIJIES"],1),"MAE Cubijíes":round(_e["Cubijíes"],2),
      "Error relativo Cubijíes %":round(100*_e["Cubijíes"]/_l["CUBIJIES"]),"Promedio semanal Flores":round(_l["FLORES"],1),"MAE Flores":round(_e["Flores"],2),
      "Error relativo Flores %":round(100*_e["Flores"]/_l["FLORES"]),"MAE todas las parroquias":round(_e["Todas las parroquias"],2),
      "Mejor modelo urbano":_mm["Urbana (Riobamba)"].idxmin(),"Pronóstico 12 sem. Riobamba":round(_t["RIOBAMBA"]),
      "Pronóstico 12 sem. Cubijíes":round(_t["CUBIJIES"],1),"Pronóstico 12 sem. Flores":round(_t["FLORES"],1)}
    cmp_=pd.concat([cmp_,pd.DataFrame([_row])],ignore_index=True)
cmp_=cmp_.drop(columns=["Alertas altas (12 sem × parroquias)"],errors="ignore")
cmp_["Alertas (altas o medias, 12 semanas)"]=cmp_["escenario"].map(_m)
esc=dict(pron={"A":pron_esc("A"),"AB":pron_esc("AB"),**_pe},comparacion=cmp_.to_dict("records"),terminos=ter.to_dict("records"))
D=dict(geo=feats,pron=pron,metricas=mae,resumen=res,azar=azar,rv=rv,variables=var,mensual=mens,cambio=cambio,backtest=back,
       codigo=cod,tipo=tipo,antes=av,porano=pa,abigeato=ab,esc=esc,generado=dt.date.today().isoformat())
import re
s=json.dumps(D,ensure_ascii=False,separators=(",",":"),default=str)
s=re.sub(r"\bNaN\b","null",s)
dst=os.path.join(R,"dashboard_next","data","data.json")
with open(dst,"w",encoding="utf8") as f: f.write(s)
print("OK ->",os.path.normpath(dst))