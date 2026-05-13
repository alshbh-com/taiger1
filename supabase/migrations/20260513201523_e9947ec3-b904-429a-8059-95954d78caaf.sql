
-- Add missing columns
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS company_id uuid REFERENCES public.companies(id) ON DELETE SET NULL;
ALTER TABLE public.companies ADD COLUMN IF NOT EXISTS agreement_price numeric DEFAULT 0;
ALTER TABLE public.offices
  ADD COLUMN IF NOT EXISTS owner_phone text,
  ADD COLUMN IF NOT EXISTS specialty text,
  ADD COLUMN IF NOT EXISTS notes text;

ALTER TABLE public.diaries
  ADD COLUMN IF NOT EXISTS lock_status_updates boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS prevent_new_orders boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_closed boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS diary_number serial;

-- Convert coverage_areas to text
ALTER TABLE public.profiles ALTER COLUMN coverage_areas TYPE text USING array_to_string(coverage_areas, ', ');

-- Add expenses.office_id and cash_flow_entries.office_id
ALTER TABLE public.expenses ADD COLUMN IF NOT EXISTS office_id uuid REFERENCES public.offices(id) ON DELETE SET NULL;
ALTER TABLE public.cash_flow_entries ADD COLUMN IF NOT EXISTS office_id uuid REFERENCES public.offices(id) ON DELETE SET NULL;

-- Add courier_collections.order_id (used in CourierOrders)
ALTER TABLE public.courier_collections ADD COLUMN IF NOT EXISTS order_id uuid REFERENCES public.orders(id) ON DELETE SET NULL;

-- Lock down SECURITY DEFINER functions: revoke from public/anon, grant to authenticated
REVOKE EXECUTE ON FUNCTION public.has_role(uuid, app_role) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.is_owner_or_admin(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.log_activity(text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_role(uuid, app_role) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_owner_or_admin(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_activity(text, jsonb) TO authenticated;

-- Fix set_updated_at search_path
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;
