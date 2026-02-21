-- FinanceFlow: cutoff_day obligatorio para tarjetas de crédito
-- Las tarjetas de crédito deben tener fecha de corte para calcular el saldo por período.

-- Asignar valor por defecto a tarjetas de crédito existentes sin cutoff
UPDATE cards
SET cutoff_day = 15
WHERE type = 'credit' AND cutoff_day IS NULL;

-- Constraint: las tarjetas de crédito deben tener cutoff_day
ALTER TABLE cards
  DROP CONSTRAINT IF EXISTS chk_credit_cutoff_required;

ALTER TABLE cards
  ADD CONSTRAINT chk_credit_cutoff_required
  CHECK (type != 'credit' OR (cutoff_day IS NOT NULL AND cutoff_day >= 1 AND cutoff_day <= 31));
