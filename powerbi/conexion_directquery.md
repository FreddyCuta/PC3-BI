# Conexión Azure SQL → Power BI Desktop

> SQL ya está preparado (23/11/2026), pero **no se generó `.pbix` ni se abrió Power BI Service**.
> Servidor real: `sql-tobotex-pc3.database.windows.net`. Base: `sqldb-tobotex`.
> Usuario recomendado: tu cuenta de Entra `edward_oliva2002@outlook.com` (sin contraseña nueva).
> Alternativa: `bi_reader` con contraseña SQL, sin reutilizar secretos del repositorio.

## Ruta principal: DirectQuery (manual §9.2)

1. Abrir Power BI Desktop en Windows y guardar como `tobotex_pc3.pbix`.
2. **Inicio > Obtener datos > Azure > Azure SQL Database**.
3. Servidor: `sql-tobotex-pc3.database.windows.net`; base: `sqldb-tobotex`.
4. Seleccionar **DirectQuery**. Consulta SQL avanzada vacía: usar vistas del navegador.
5. Autenticación recomendada: **Microsoft account / Azure Active Directory - Universal with MFA**
   (el nombre cambia según versión). Inicia sesión con `edward_oliva2002@outlook.com`.
   Ya existe un usuario contenido de Entra con ese nombre y permisos de sólo lectura en `bi`.
   Si prefieres SQL Authentication, usa `bi_reader` con una contraseña nueva guardada fuera del repo.
   No uses Windows Authentication ni la cuenta administradora `tobotex`.
6. Elegir el nivel correcto de servidor/base para guardar credenciales. Si aparece un aviso de firewall,
   la IP actual ya está permitida; desde otra red hay que agregar esa IP en el servidor SQL.
7. Marcar vistas:

| Vista | Nombre de consulta |
|---|---|
| `bi.v_despacho` | `Despacho` |
| `bi.v_reclamo` | `Reclamo` |
| `bi.v_dim_fecha` | `Fecha` |
| `bi.v_dim_tienda_bi` | `Tienda` |
| `bi.v_dim_marca_bi` | `Marca` |
| `bi.v_dim_producto_bi` | `Producto` |
| `bi.v_corte_publicado` | `Corte` |
| `bi.v_periodo_revisado` | `Revisiones` |
| `bi.v_comparacion_cortes` | `Comparacion` |
| `bi.v_k1`, `bi.v_k2`, `bi.v_k3`, `bi.v_k4`, `bi.v_k6` | `K1`, `K2`, `K3`, `K4`, `K6` |
| `bi.v_k5` | `LineasCorte` (sin filtro temporal, §10.7) |

8. **Transformar datos**: `fecha` como Date, importes decimal fijo, cantidades entero, claves texto.
9. **No combinar** los dos hechos con Merge. El doble conteo se evita agregando por separado.
10. Cerrar y aplicar; comprobar en vista Modelo que cada tabla queda en modo DirectQuery.
11. Crear relaciones (`modelo_relaciones.md`) y medidas (`medidas.dax`).

El conector admite Import y DirectQuery. Nombres de pantalla pueden variar por versión/idioma.
[Conector oficial](https://learn.microsoft.com/en-us/power-query/connectors/azure-sql-database).

## Ruta alternativa: Import (manual §9.3)

1. Copia de trabajo del `.pbix` o archivo nuevo; repetir conexión seleccionando **Import**.
2. Mismas vistas, nombres, transformaciones, relaciones y medidas.
3. Cargar sólo cuando el pipeline haya terminado de publicar; detener publicaciones mientras
   se actualizan todas las tablas. **Inicio > Actualizar**, verificar corte/conteos/KPIs y guardar.
4. Import muestra la última copia cargada: publicar un lote en Azure **no** actualiza el `.pbix`
   ni el modelo en Service. Requiere actualización tras publicación (manual §11.3).

Si hay publicaciones concurrentes durante el Import, tablas distintas pueden capturar cortes
distintos. Para operación concurrente harían falta consultas fijadas al mismo `corte_seq` y
actualización coordinada.

## Si existe un informe previo en otro equipo (manual §9.4)

No se encontró `.pbix` en `PC3-BI/powerbi/`. Si aparece: guardar copia, revisar
**Transformar datos > Configuración de origen de datos**, conservar nombres de consulta y
contrato de columnas, reparar relaciones y medidas, validar visual por visual y conciliar
K2/K3 antes de eliminar consultas antiguas. Un dashboard contiene mosaicos vinculados a
informes/modelos: no se importan filas directamente sobre sus tarjetas.

## Prerrequisitos SQL del lector

`bi_reader` no lee `cur`. Las vistas `bi.v_dim_*` se versionan en
`sql/fase3/20_dimensiones_powerbi.sql` y **ya fueron creadas** en `sqldb-tobotex`.
La verificación de unicidad devolvió cero filas para `marca_codigo` y `tienda`.
El usuario de Entra `edward_oliva2002@outlook.com` también tiene `GRANT SELECT` en `bi` y
`DENY SELECT` en `ctl`, `cur`, `quar`, `stg` y `trusted`. No ocultar duplicados arbitrariamente;
si hay colisión de marca, cambiar el diseño de clave.

No usar `v_dim_tienda_bi` con múltiples versiones SCD2 de LEO: la asignación temporal ya está
resuelta en `bi.v_despacho`/`bi.v_reclamo`. Para filtrar zona común a ambos hechos, crear una
dimensión separada de zonas únicas sin reemplazar la asignación histórica.
