CREATE TABLE ctl.lote (
  lote_id VARCHAR(10) NOT NULL, intento INT NOT NULL, fuente VARCHAR(20) NOT NULL,
  fecha_recepcion DATE NOT NULL, archivo NVARCHAR(300) NULL,
  filas_leidas INT NULL, filas_ins INT NULL, filas_upd INT NULL, filas_omit INT NULL, filas_rech INT NULL,
  estado VARCHAR(20) NOT NULL, mensaje NVARCHAR(400) NULL, corte_seq INT NULL, run_id VARCHAR(80) NULL,
  inicio_utc DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(), fin_utc DATETIME2(0) NULL,
  CONSTRAINT pk_lote PRIMARY KEY (lote_id, intento, fuente));

CREATE TABLE ctl.corte (
  corte_seq INT NOT NULL PRIMARY KEY, corte_id VARCHAR(20) NOT NULL UNIQUE,
  estado VARCHAR(12) NOT NULL,
  lote_id VARCHAR(10) NOT NULL, intento INT NOT NULL,
  creado_utc DATETIME2(0) NOT NULL, publicado_utc DATETIME2(0) NULL);

CREATE TABLE ctl.corte_objeto (
  corte_seq INT NOT NULL, objeto VARCHAR(40) NOT NULL, estado VARCHAR(12) NOT NULL, filas INT NOT NULL,
  CONSTRAINT pk_corte_objeto PRIMARY KEY (corte_seq, objeto));

CREATE TABLE ctl.corte_vigente (id INT NOT NULL PRIMARY KEY CHECK (id = 1), corte_seq INT NOT NULL);
INSERT INTO ctl.corte_vigente VALUES (1, 0);

CREATE TABLE ctl.contrato_campo (
  fuente VARCHAR(20) NOT NULL, version_contrato VARCHAR(5) NOT NULL, campo SYSNAME NOT NULL,
  tipo VARCHAR(20) NOT NULL, requerido BIT NOT NULL,
  CONSTRAINT pk_contrato_campo PRIMARY KEY (fuente, version_contrato, campo));

CREATE TABLE ctl.periodo_revisado (
  corte_seq INT NOT NULL, periodo CHAR(7) NOT NULL, hecho VARCHAR(20) NOT NULL, filas INT NOT NULL,
  CONSTRAINT pk_periodo_revisado PRIMARY KEY (corte_seq, periodo, hecho));