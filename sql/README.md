# SQL — Tobotex

Colocar aquí scripts SQL de Fase 2/Fase 3 para el caso Tobotex.

## Orden esperado (referencia Fase 2)

1. `00_esquemas.sql`
2. `01_control.sql`
3. `02_stg.sql`
4. `03_trusted.sql`
5. `04_curated.sql`
6. `05_seed.sql`
7. `06_sp_control.sql`
8. `07_sp_trusted.sql`
9. `08_sp_corte.sql`
10. `09_vistas_bi.sql`
11. `10_seguridad.sql`
12. `11_kpis.sql`
13. `12_costos_consultas.sql` (si aplica)
14. `98_reset_datos.sql`, `99_limpieza.sql` (uso controlado)

## Fase 3 (preparación local, no ejecutada)

Los scripts propuestos están en `fase3/` con orden y decisiones documentadas en
`fase3/README.md`. Los originales de Fase 2 en `Querys/` se conservan sin modificar.

## Reglas

- No incluir contraseñas reales.
- Versionar cambios y anotar desviaciones en `docs/estado_relevo.md`.
- Ejecutar primero en entorno de prueba cuando se preparen P1–P8.
