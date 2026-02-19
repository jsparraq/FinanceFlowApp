-- FinanceFlow: RLS y políticas por usuario
-- Las transacciones e inversiones se asocian al usuario autenticado (auth.uid()).
-- Trigger asegura user_id en INSERT sin depender del cliente.

-- Transacciones: solo el dueño puede ver/crear/actualizar/eliminar
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- Asignar user_id automáticamente en INSERT (el cliente no envía user_id; el servidor usa el JWT)
CREATE OR REPLACE FUNCTION set_user_id_on_insert()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.user_id IS NULL THEN
    NEW.user_id := auth.uid();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER set_transactions_user_id
  BEFORE INSERT ON transactions
  FOR EACH ROW EXECUTE FUNCTION set_user_id_on_insert();

CREATE POLICY "Users can read own transactions"
  ON transactions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own transactions"
  ON transactions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own transactions"
  ON transactions FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own transactions"
  ON transactions FOR DELETE
  USING (auth.uid() = user_id);

-- Categorías: lectura para usuarios autenticados (son globales por ahora)
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read categories"
  ON categories FOR SELECT
  TO authenticated
  USING (true);

-- Inversiones: mismo patrón que transacciones
ALTER TABLE investments ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER set_investments_user_id
  BEFORE INSERT ON investments
  FOR EACH ROW EXECUTE FUNCTION set_user_id_on_insert();

CREATE POLICY "Users can read own investments"
  ON investments FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own investments"
  ON investments FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own investments"
  ON investments FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own investments"
  ON investments FOR DELETE
  USING (auth.uid() = user_id);
