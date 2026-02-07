-- FinanceFlow: Schema inicial para transacciones y categorías
-- Ejecutar en Supabase SQL Editor o via Supabase CLI

-- Extensión para UUIDs (normalmente ya está en Supabase)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Tabla de categorías
CREATE TABLE IF NOT EXISTS categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    icon_name TEXT DEFAULT 'folder',
    color_hex TEXT DEFAULT '#6366F1',
    transaction_type TEXT NOT NULL CHECK (transaction_type IN ('income', 'expense')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (name, transaction_type)
);

-- Tabla de transacciones
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    amount DECIMAL(18, 2) NOT NULL,
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    note TEXT,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    -- Para RLS: vincular con auth.users cuando agregues autenticación
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Índices para consultas frecuentes
CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_category_id ON transactions(category_id);
CREATE INDEX IF NOT EXISTS idx_categories_transaction_type ON categories(transaction_type);

-- Tabla de inversiones (preparada para expansión futura)
CREATE TABLE IF NOT EXISTS investments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    symbol TEXT,
    type TEXT NOT NULL CHECK (type IN ('stock', 'fund', 'crypto', 'other')),
    amount_invested DECIMAL(18, 2) NOT NULL,
    current_value DECIMAL(18, 2),
    quantity DECIMAL(18, 6) DEFAULT 1,
    currency TEXT DEFAULT 'USD',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE
);

-- Row Level Security (RLS) - descomentar cuando agregues auth
-- ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE investments ENABLE ROW LEVEL SECURITY;

-- Política ejemplo para transacciones (usar user_id del JWT):
-- CREATE POLICY "Users can manage own transactions"
--   ON transactions FOR ALL
--   USING (auth.uid() = user_id)
--   WITH CHECK (auth.uid() = user_id);

-- Datos iniciales de categorías
INSERT INTO categories (name, icon_name, color_hex, transaction_type) VALUES
    ('Alimentación', 'fork.knife', '#10B981', 'expense'),
    ('Transporte', 'car.fill', '#3B82F6', 'expense'),
    ('Vivienda', 'house.fill', '#8B5CF6', 'expense'),
    ('Entretenimiento', 'gamecontroller.fill', '#EC4899', 'expense'),
    ('Salud', 'heart.fill', '#EF4444', 'expense'),
    ('Otros', 'ellipsis.circle', '#6B7280', 'expense'),
    ('Salario', 'banknote.fill', '#10B981', 'income'),
    ('Freelance', 'laptopcomputer', '#3B82F6', 'income'),
    ('Inversiones', 'chart.line.uptrend.xyaxis', '#8B5CF6', 'income'),
    ('Otros', 'plus.circle', '#6B7280', 'income')
ON CONFLICT (name, transaction_type) DO NOTHING;
