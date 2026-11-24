# Anexo E — Control común por cortes

> Responsable: Rolando ejecuta; Edward verifica/reutiliza en pruebas. Usar `sqldb-control` o espacio aislado.

## Tabla por corte y mes

| Corte | Mes | Bruto K1 (SQL) | Devuelto (SQL) | Neto K2 (SQL) | Bruto (indep.) | Devuelto (indep.) | Neto (indep.) | Coincide | Evidencia |
|---|---|---:|---:|---:|---:|---:|---:|---|---|
| C0 | 2026-01 |  |  |  | 100.00 | 0.00 | 100.00 |  |  |
| C0 | 2026-02 |  |  |  | 120.00 | 15.00 | 105.00 |  |  |
| C0 | 2026-03 |  |  |  | 120.00 | 8.00 | 112.00 |  |  |
| C1 | 2026-01 |  |  |  | 100.00 | 0.00 | 100.00 |  |  |
| C1 | 2026-02 |  |  |  | 120.00 | 15.00 | 105.00 |  |  |
| C1 | 2026-03 |  |  |  | 160.00 | 8.00 | 152.00 |  |  |
| C2 | 2026-01 |  |  |  | 100.00 | 0.00 | 100.00 |  |  |
| C2 | 2026-02 |  |  |  | 120.00 | 19.00 | 101.00 |  |  |
| C2 | 2026-03 |  |  |  | 160.00 | 8.00 | 152.00 |  |  |
| C3 | 2026-01 |  |  |  | 100.00 | 0.00 | 100.00 |  |  |
| C3 | 2026-02 |  |  |  | 120.00 | 19.00 | 101.00 |  |  |
| C3 | 2026-03 |  |  |  | 180.00 | 13.00 | 167.00 |  |  |

## Adaptación reproducible y política C8 (preparación local)

- Originales en `carga/Carga/datos/control_anexoE/` **no modificados**. La adaptación se genera con
  `carga/Carga/adaptar_control.py` en `carga/Carga/datos/control_adaptado/`, con manifiestos y
  hashes propios. Mapeo completo en `contratos/POLITICAS_CASO.md`.
- `id_movimiento`/`contrato` = `linea`; `tienda` = `sede`; `zona_comercial` = `region`;
  `fecha_salida` = `fecha_venta`; `fecha_reclamo` = `fecha_devolucion`; `marca` = `CONTROL`;
  cantidades `1` son artificiales y `detalle` fijo `1`.
- Fechas de recepción L0–L3 son **supuestos de prueba declarados** en los manifiestos, no fechas
  originales del negocio. Productos P1/P2 y motivo CONTROL se insertan con
  `sql/fase3/21_control_dimensiones.sql` (no ejecutado).
- **C8 control = `0.2500` con comparación estricta `>`** (Tobotex `0.2000`). Es una decisión
  propuesta para que 25 % exacto no bloquee L1; **no es una regla del enunciado oficial**.
  Si se exige 20 % universal, registrar incompatibilidad y **no declarar P2 control aprobada**.
- No usar K5/K6 de esta adaptación para análisis de negocio: las cantidades son artificiales.
- Columnas SQL y coincidencia con el cálculo independiente siguen **PENDIENTES**: no hay base
  de control conectada ni resultados observados. Los valores de la tabla son esperados.

## Explicaciones obligatorias

- [ ] C1: V04 +10, V05 +30, V06 cuarentena.
- [ ] P3 reenvío L1: 0 ins, 0 upd, 3 omit, 1 rech; sin cambio de corte/KPI.
- [ ] C2: D04 suma 4 en febrero; enero sin cambio; D04 región Norte.
- [ ] P8: durante falla marzo 160/8/152; nunca 180/8/172; tras reintento 180/13/167.
