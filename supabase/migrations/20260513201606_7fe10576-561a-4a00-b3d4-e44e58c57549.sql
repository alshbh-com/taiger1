
ALTER TABLE public.advances
  ADD COLUMN IF NOT EXISTS reason text,
  ADD COLUMN IF NOT EXISTS type text DEFAULT 'advance',
  ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.courier_bonuses ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.office_daily_expenses ADD COLUMN IF NOT EXISTS created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.cash_flow_entries ADD COLUMN IF NOT EXISTS reason text;
