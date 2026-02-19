-- FinanceFlow: Fecha de corte y fecha límite de pago para tarjetas de crédito
-- Día del mes (1-31) para corte y límite de pago

ALTER TABLE cards
  ADD COLUMN IF NOT EXISTS cutoff_day INTEGER CHECK (cutoff_day >= 1 AND cutoff_day <= 31),
  ADD COLUMN IF NOT EXISTS payment_due_day INTEGER CHECK (payment_due_day >= 1 AND payment_due_day <= 31);
