# Conexión Azure SQL → Power BI Desktop

> Estado local: **no se generó `.pbix`**. No hay Power BI Desktop, credenciales ni base publicada
> en este entorno. Esto es un procedimiento versionado del manual §9, no evidencia de conexión.

## Ruta principal: DirectQuery (manual §9.2)

1. Abrir Power BI Desktop en Windows y guardar como `tobotex_pc3.pbix`.
2. **Inicio > Obtener datos > Azure > Azure SQL Database**.
3. Servidor completo `TU_SERVIDOR.database.windows.net`; base `sqldb-tobotex`.
4. Seleccionar **DirectQuery**. Consulta SQL avanzada vacía: usar vistas del navegador.
5. Autenticación **Database**, usuario `bi_reader` y secreto nuevo de la sesión.
   No usar Windows Authentication para ese usuario contenido. No versionar el secreto.
6. Elegir el nivel correcto de servidor/base para guardar credenciales.
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
`sql/fase3/20_dimensiones_powerbi.sql` y deben crearse como administrador antes de conectar.
Verificar unicidad de `marca_codigo` y `tienda`: ambas consultas deben devolver cero filas.
No ocultar duplicados arbitrariamente; si hay colisión de marca, cambiar el diseño de clave.

No usar `v_dim_tienda_bi` con múltiples versiones SCD2 de LEO: la asignación temporal ya está
resuelta en `bi.v_despacho`/`bi.v_reclamo`. Para filtrar zona común a ambos hechos, crear una
dimensión separada de zonas únicas sin reemplazar la asignación histórica.
