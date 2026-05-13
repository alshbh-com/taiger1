
ALTER TABLE public.offices ADD COLUMN IF NOT EXISTS can_add_orders boolean DEFAULT true;
ALTER TABLE public.office_payments ADD COLUMN IF NOT EXISTS type text DEFAULT 'payment';
ALTER TABLE public.office_daily_expenses ADD COLUMN IF NOT EXISTS category text;
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS address text,
  ADD COLUMN IF NOT EXISTS notes text;
