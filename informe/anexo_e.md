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

## Explicaciones obligatorias

- [ ] C1: V04 +10, V05 +30, V06 cuarentena.
- [ ] P3 reenvío L1: 0 ins, 0 upd, 3 omit, 1 rech; sin cambio de corte/KPI.
- [ ] C2: D04 suma 4 en febrero; enero sin cambio; D04 región Norte.
- [ ] P8: durante falla marzo 160/8/152; nunca 180/8/172; tras reintento 180/13/167.
