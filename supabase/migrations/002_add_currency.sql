-- =============================================
-- ADD CURRENCY COLUMN TO USERS TABLE
-- =============================================

-- Add currency_code column if it doesn't exist
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS currency_code TEXT NOT NULL DEFAULT 'GBP';

-- Create index for currency_code for faster queries
CREATE INDEX IF NOT EXISTS users_currency_code_idx ON public.users(currency_code);

-- Update any existing users without currency to GBP
UPDATE public.users 
SET currency_code = 'GBP' 
WHERE currency_code IS NULL;

