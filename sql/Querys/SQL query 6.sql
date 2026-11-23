SET IDENTITY_INSERT cur.dim_tienda ON;
INSERT INTO cur.dim_tienda (tienda_sk, tienda, zona_comercial, vigente_desde, vigente_hasta, es_actual)
VALUES (-1, 'DESCONOCIDA', 'Desconocida', '1900-01-01', '9999-12-31', 1);
SET IDENTITY_INSERT cur.dim_tienda OFF;

SET IDENTITY_INSERT cur.dim_marca ON;
INSERT INTO cur.dim_marca (marca_sk, marca) VALUES (-1, N'DESCONOCIDA');
SET IDENTITY_INSERT cur.dim_marca OFF;

SET IDENTITY_INSERT cur.dim_producto ON;
INSERT INTO cur.dim_producto (producto_sk, producto, familia) VALUES (-1, 'DESCONOCIDO', 'Desconocida');
SET IDENTITY_INSERT cur.dim_producto OFF;

INSERT INTO cur.dim_producto (producto, familia) VALUES
 ('DAMASCO','Etiqueta tejida'), ('TAFETAN','Etiqueta tejida'), ('RETEJIDO','Etiqueta tejida'),
 ('TROQUELADO','Troquelado'), ('CINTA','Cinta continua');

SET IDENTITY_INSERT cur.dim_motivo ON;
INSERT INTO cur.dim_motivo (motivo_sk, motivo, es_valido) VALUES (-1, 'SIN_MOTIVO', 0);
SET IDENTITY_INSERT cur.dim_motivo OFF;

INSERT INTO cur.dim_motivo (motivo, es_valido) VALUES ('DEFECTO_TEJIDO',1), ('COLOR',1), ('MEDIDA',1), ('CANTIDAD',1);

INSERT INTO ctl.contrato_campo (fuente, version_contrato, campo, tipo, requerido) VALUES
 ('despacho','1.0','id_movimiento','string',1), ('despacho','1.0','version','int',1),
 ('despacho','1.0','fecha_salida','date',1), ('despacho','1.0','tienda','string',1),
 ('despacho','1.0','marca','string',1), ('despacho','1.0','producto','string',1),
 ('despacho','1.0','contrato','string',1), ('despacho','1.0','detalle','string',1),
 ('despacho','1.0','cantidad_contratada','int',1), ('despacho','1.0','cantidad_despachada','int',1),
 ('despacho','1.0','importe_pen','decimal(18,2)',1), ('despacho','1.0','fecha_actualizacion_origen','datetime',0),
 ('reclamo','1.0','id_reclamo','string',1), ('reclamo','1.0','id_movimiento','string',1),
 ('reclamo','1.0','fecha_reclamo','date',1), ('reclamo','1.0','cantidad_devuelta','int',1),
 ('reclamo','1.0','importe_devuelto_pen','decimal(18,2)',1), ('reclamo','1.0','motivo','string',0),
 ('reclamo','1.0','fecha_actualizacion_origen','datetime',0),
 ('tienda','1.0','tienda','string',1), ('tienda','1.0','zona_comercial','string',1),
 ('tienda','1.0','vigente_desde','date',1), ('tienda','1.0','vigente_hasta','date',0);