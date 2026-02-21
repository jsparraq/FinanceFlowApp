-- FinanceFlow: Pago de tarjeta de crédito
-- credit_card_paid_id: cuando la transacción es un pago a una tarjeta de crédito,
-- indica qué tarjeta se está pagando. card_id indica la fuente (débito/efectivo).

ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS credit_card_paid_id UUID REFERENCES cards(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_credit_card_paid_id ON transactions(credit_card_paid_id);

COMMENT ON COLUMN transactions.credit_card_paid_id IS 'Tarjeta de crédito que se está pagando. Solo aplica cuando type=expense y es un pago.';

-- Categoría para pagos de tarjeta de crédito
INSERT INTO categories (name, icon_name, color_hex, transaction_type) VALUES
  ('Pago de tarjeta de crédito', 'creditcard.fill', '#6366F1', 'expense')
ON CONFLICT (name, transaction_type) DO NOTHING;
