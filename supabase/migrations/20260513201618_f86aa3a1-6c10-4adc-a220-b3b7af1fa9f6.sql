
ALTER TABLE public.cash_flow_entries ADD COLUMN IF NOT EXISTS notes text;
ALTER TABLE public.office_daily_expenses ADD COLUMN IF NOT EXISTS notes text;
