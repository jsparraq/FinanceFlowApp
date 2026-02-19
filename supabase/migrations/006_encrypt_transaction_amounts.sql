-- FinanceFlow: Cifrado de montos de transacciones
-- Los montos se almacenan cifrados en el cliente; la BD solo guarda texto cifrado (base64).
-- El administrador de Supabase no puede ver los montos reales.
-- Los registros actuales son de prueba y se eliminan para reconstruir la tabla.

-- Eliminar todos los registros de prueba
-- TRUNCATE TABLE transactions;

-- Cambiar la columna amount de DECIMAL a TEXT (almacena el valor cifrado en base64)
ALTER TABLE transactions DROP COLUMN amount;
ALTER TABLE transactions ADD COLUMN amount TEXT NOT NULL;

-- Comentario para documentación
COMMENT ON COLUMN transactions.amount IS 'Monto cifrado con AES-GCM (base64). Solo el cliente con la clave del dispositivo puede descifrarlo.';
