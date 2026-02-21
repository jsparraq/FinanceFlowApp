-- Agregar columna tipo: fijo o variable (tipo de transacción por recurrencia)
-- Fijo: gastos/ingresos recurrentes (renta, salario, servicios)
-- Variable: gastos/ingresos ocasionales (compras, salidas, freelance puntual)
-- Nota: "type" ya existe para income/expense, por eso usamos "tipo"

ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS tipo TEXT DEFAULT 'variable'
  CHECK (tipo IN ('fixed', 'variable'));

COMMENT ON COLUMN transactions.tipo IS 'fixed = gasto/ingreso recurrente; variable = ocasional';
