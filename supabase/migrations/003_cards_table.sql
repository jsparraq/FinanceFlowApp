-- FinanceFlow: Tabla de tarjetas (débito y crédito)
-- Ejecutar en Supabase SQL Editor o via Supabase CLI

-- Tabla de tarjetas
CREATE TABLE IF NOT EXISTS cards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('debit', 'credit')),
    credit_limit DECIMAL(18, 2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Índices para consultas frecuentes
CREATE INDEX IF NOT EXISTS idx_cards_user_id ON cards(user_id);
CREATE INDEX IF NOT EXISTS idx_cards_type ON cards(type);

-- RLS
ALTER TABLE cards ENABLE ROW LEVEL SECURITY;

-- Trigger para asignar user_id automáticamente en INSERT
CREATE TRIGGER set_cards_user_id
  BEFORE INSERT ON cards
  FOR EACH ROW EXECUTE FUNCTION set_user_id_on_insert();

-- Políticas RLS
CREATE POLICY "Users can read own cards"
  ON cards FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own cards"
  ON cards FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own cards"
  ON cards FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own cards"
  ON cards FOR DELETE
  USING (auth.uid() = user_id);

-- Columna card_id en transacciones (asignar transacciones a tarjetas)
ALTER TABLE transactions
  ADD COLUMN IF NOT EXISTS card_id UUID REFERENCES cards(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_card_id ON transactions(card_id);
