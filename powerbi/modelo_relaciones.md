# Modelo y relaciones (manual §10.1)

> Estado local: especificación. Sin `.pbix` generado; las relaciones están pendientes de crear
> en Power BI Desktop. No marcar como implementadas hasta guardar la captura del modelo.

## Relaciones activas

Todas 1 a muchos, dirección de filtro única:

```text
Fecha[fecha]        (1) a Despacho[fecha]          (*)
Fecha[fecha]        (1) a Reclamo[fecha]           (*)
Tienda[tienda]      (1) a Despacho[tienda]         (*)
Tienda[tienda]      (1) a Reclamo[tienda]          (*)
Marca[marca_codigo] (1) a Despacho[marca_codigo]   (*)
Marca[marca_codigo] (1) a Reclamo[marca_codigo]    (*)
Producto[producto]  (1) a Despacho[producto]       (*)
Producto[producto]  (1) a Reclamo[producto]        (*)
```

## Reglas

1. Eliminar relaciones automáticas incorrectas antes de crear éstas.
2. **No** relacionar `Despacho` directamente con `Reclamo` por `id_movimiento`: agregar por
   separado evita inflar el bruto por reclamos múltiples.
3. `Corte`, `Revisiones` y `Comparacion` quedan desconectadas inicialmente.
4. Marcar `Fecha` como tabla de fechas, columna `fecha`.
5. Ordenar `nombre_mes` por `mes`.
6. Usar `Fecha[periodo]` en ejes y segmentadores: `YYYY-MM` ordena por año y mes.
7. Ocultar columnas técnicas no necesarias para el usuario.
8. Los segmentadores de fecha/tienda/marca/producto salen de las dimensiones compartidas.
   Un segmentador de `Despacho[tienda]` **no** filtra `Reclamo` con este modelo.
9. En la página 3, `LineasCorte` (`bi.v_k5`) se relaciona con Tienda y Marca, **no** con Fecha.

## Verificación previa en SQL

Ejecutar como administrador `sql/fase3/20_dimensiones_powerbi.sql`. Ambas consultas de unicidad
deben devolver cero filas:

```sql
SELECT marca_codigo, COUNT(*) AS filas
FROM bi.v_dim_marca_bi GROUP BY marca_codigo HAVING COUNT(*) > 1;

SELECT tienda, COUNT(*) AS filas
FROM bi.v_dim_tienda_bi GROUP BY tienda HAVING COUNT(*) > 1;
```

Si `v_dim_tienda_bi` tuviera varias filas por tienda (LEO), no usarla como dimensión de hechos.
