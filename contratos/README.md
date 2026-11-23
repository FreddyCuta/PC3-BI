# Contratos de datos

Guardar contratos versionados por fuente (`*_v1.json`, etc.).

## Mínimo por contrato

- `fuente`, `version_contrato`, `formato`, `zona_horaria`.
- `clave_negocio`, `regla_version`.
- `campos`: nombre, tipo, requerido, rol/sensible si aplica.
- `cambios_admitidos` / `cambios_no_admitidos`.

## Coherencia

La definición debe coincidir con `ctl.contrato_campo` y con la validación C1 del pipeline/procedimientos.
