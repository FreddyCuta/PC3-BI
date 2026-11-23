# Datos

## Estructura

- `generador/`: scripts con semilla 2026 y cálculos independientes.
- `tobotex/L0..L3,LX`: archivos por lote + `manifiesto.json`.
- `control_anexoE/L0..L3`: archivos por lote + manifiesto.

## Reglas

- No editar archivos recibidos en raw; las correcciones se entregan como lote nuevo.
- Verificar `sha256` y conteo de filas contra manifiesto.
- Declarar datos simulados en README e informe.
