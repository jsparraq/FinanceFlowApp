-- FinanceFlow: Tarjeta sistema "Efectivo" para pagos en efectivo
-- Visible para todos los usuarios, registro fijo en la tabla cards.

-- 1. Permitir tipo 'cash' en la tabla cards
ALTER TABLE cards DROP CONSTRAINT IF EXISTS cards_type_check;
ALTER TABLE cards ADD CONSTRAINT cards_type_check
  CHECK (type IN ('debit', 'credit', 'cash'));

-- 2. Permitir user_id NULL para tarjetas del sistema (visibles a todos)
-- La columna user_id ya permite NULL por defecto en PostgreSQL.

-- 3. Modificar política SELECT para que los usuarios puedan ver:
--    - Sus propias tarjetas (user_id = auth.uid())
--    - Tarjetas del sistema (user_id IS NULL)
DROP POLICY IF EXISTS "Users can read own cards" ON cards;
CREATE POLICY "Users can read own cards"
  ON cards FOR SELECT
  USING (auth.uid() = user_id OR user_id IS NULL);

-- 4. Evitar que el trigger asigne user_id a tarjetas del sistema
-- (cuando user_id ya viene explícitamente como NULL, el trigger lo deja así
--  porque auth.uid() en migración es NULL; en inserts normales el cliente
--  no envía user_id así que se asigna correctamente)

-- 5. Insertar tarjeta "Efectivo" como registro del sistema (user_id = NULL)
-- Usamos un UUID fijo para referencias estables en transacciones
INSERT INTO cards (id, name, type, credit_limit, created_at, updated_at, user_id)
VALUES (
  '00000000-0000-0000-0000-000000000001'::uuid,
  'Efectivo',
  'cash',
  NULL,
  NOW(),
  NOW(),
  NULL
)
ON CONFLICT (id) DO NOTHING;
