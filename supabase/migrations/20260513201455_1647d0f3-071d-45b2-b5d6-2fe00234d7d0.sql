
-- =========================================
-- ROLES ENUM + USER_ROLES + has_role function
-- =========================================
CREATE TYPE public.app_role AS ENUM ('owner', 'admin', 'courier', 'office');

CREATE TABLE public.user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role app_role NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, role)
);
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.has_role(_user_id uuid, _role app_role)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role = _role)
$$;

CREATE OR REPLACE FUNCTION public.is_owner_or_admin(_user_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.user_roles WHERE user_id = _user_id AND role IN ('owner','admin'))
$$;

CREATE POLICY "users see own roles" ON public.user_roles FOR SELECT USING (auth.uid() = user_id OR public.is_owner_or_admin(auth.uid()));
CREATE POLICY "admins manage roles" ON public.user_roles FOR ALL USING (public.is_owner_or_admin(auth.uid())) WITH CHECK (public.is_owner_or_admin(auth.uid()));

-- =========================================
-- PROFILES
-- =========================================
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name text NOT NULL DEFAULT '',
  phone text,
  email text,
  salary numeric DEFAULT 0,
  commission_amount numeric DEFAULT 0,
  coverage_areas text[],
  office_id uuid,
  can_add_orders boolean DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "view own or admin all profiles" ON public.profiles FOR SELECT USING (auth.uid() = user_id OR public.is_owner_or_admin(auth.uid()));
CREATE POLICY "update own or admin profiles" ON public.profiles FOR UPDATE USING (auth.uid() = user_id OR public.is_owner_or_admin(auth.uid()));
CREATE POLICY "admin insert profiles" ON public.profiles FOR INSERT WITH CHECK (public.is_owner_or_admin(auth.uid()) OR auth.uid() = user_id);
CREATE POLICY "admin delete profiles" ON public.profiles FOR DELETE USING (public.is_owner_or_admin(auth.uid()));

-- =========================================
-- USER_PERMISSIONS
-- =========================================
CREATE TABLE public.user_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  section text NOT NULL,
  permission text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, section, permission)
);
ALTER TABLE public.user_permissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "view own perms" ON public.user_permissions FOR SELECT USING (auth.uid() = user_id OR public.is_owner_or_admin(auth.uid()));
CREATE POLICY "admin manage perms" ON public.user_permissions FOR ALL USING (public.is_owner_or_admin(auth.uid())) WITH CHECK (public.is_owner_or_admin(auth.uid()));

-- =========================================
-- OFFICES
-- =========================================
CREATE TABLE public.offices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  owner_name text,
  phone text,
  address text,
  office_commission numeric DEFAULT 0,
  prevent_new_orders boolean DEFAULT false,
  lock_status_updates boolean DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.offices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "all authenticated read offices" ON public.offices FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin manage offices" ON public.offices FOR ALL USING (public.is_owner_or_admin(auth.uid())) WITH CHECK (public.is_owner_or_admin(auth.uid()));

-- =========================================
-- DELIVERY_PRICES
-- =========================================
CREATE TABLE public.delivery_prices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  office_id uuid NOT NULL REFERENCES public.offices(id) ON DELETE CASCADE,
  governorate text NOT NULL,
  price numeric NOT NULL DEFAULT 0,
  pickup_price numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.delivery_prices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read delivery_prices" ON public.delivery_prices FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin manage delivery_prices" ON public.delivery_prices FOR ALL USING (public.is_owner_or_admin(auth.uid())) WITH CHECK (public.is_owner_or_admin(auth.uid()));

-- =========================================
-- PRODUCTS
-- =========================================
CREATE TABLE public.products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  quantity integer NOT NULL DEFAULT 0,
  price numeric DEFAULT 0,
  office_id uuid REFERENCES public.offices(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read products" ON public.products FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin manage products" ON public.products FOR ALL USING (public.is_owner_or_admin(auth.uid())) WITH CHECK (public.is_owner_or_admin(auth.uid()));

-- =========================================
-- ORDER_STATUSES
-- =========================================
CREATE TABLE public.order_statuses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  color text DEFAULT '#888888',
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.order_statuses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read order_statuses" ON public.order_statuses FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin manage order_statuses" ON public.order_statuses FOR ALL USING (public.is_owner_or_admin(auth.uid())) WITH CHECK (public.is_owner_or_admin(auth.uid()));

INSERT INTO public.order_statuses (name, color, sort_order) VALUES
  ('جديد', '#3b82f6', 1),
  ('في الطريق', '#f59e0b', 2),
  ('تم التوصيل', '#10b981', 3),
  ('مرتجع', '#ef4444', 4),
  ('ملغي', '#6b7280', 5);

-- =========================================
-- ORDERS  (with sequential numeric barcode trigger)
-- =========================================
CREATE SEQUENCE IF NOT EXISTS public.orders_barcode_seq START WITH 100001;

CREATE TABLE public.orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  barcode text UNIQUE,
  tracking_id text UNIQUE,
  customer_name text NOT NULL,
  customer_phone text NOT NULL,
  customer_code text,
  product_name text,
  product_id uuid REFERENCES public.products(id) ON DELETE SET NULL,
  quantity integer DEFAULT 1,
  price numeric NOT NULL DEFAULT 0,
  delivery_price numeric NOT NULL DEFAULT 0,
  shipping_paid numeric DEFAULT 0,
  partial_amount numeric DEFAULT 0,
  address text,
  notes text,
  color text,
  size text,
  priority text DEFAULT 'normal',
  office_id uuid REFERENCES public.offices(id) ON DELETE SET NULL,
  courier_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  status_id uuid REFERENCES public.order_statuses(id) ON DELETE SET NULL,
  is_closed boolean NOT NULL DEFAULT false,
  is_courier_closed boolean NOT NULL DEFAULT false,
  is_settled boolean NOT NULL DEFAULT false,
  is_archived boolean NOT NULL DEFAULT false,
  returned_to_sender boolean NOT NULL DEFAULT false,
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
CREATE INDEX idx_orders_office ON public.orders(office_id);
CREATE INDEX idx_orders_courier ON public.orders(courier_id);
CREATE INDEX idx_orders_status ON public.orders(status_id);
CREATE INDEX idx_orders_created ON public.orders(created_at DESC);

CREATE OR REPLACE FUNCTION public.generate_order_barcode()
RETURNS TRIGGER LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  IF NEW.barcode IS NULL OR NEW.barcode = '' THEN
    NEW.barcode := nextval('public.orders_barcode_seq')::text;
  END IF;
  IF NEW.tracking_id IS NULL OR NEW.tracking_id = '' THEN
    NEW.tracking_id := NEW.barcode;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_orders_barcode BEFORE INSERT ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.generate_order_barcode();

CREATE POLICY "read orders" ON public.orders FOR SELECT TO authenticated USING (
  public.is_owner_or_admin(auth.uid())
  OR auth.uid() = courier_id
  OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.user_id = auth.uid() AND p.office_id = orders.office_id)
);
CREATE POLICY "admin manage orders" ON public.orders FOR ALL USING (public.is_owner_or_admin(auth.uid())) WITH CHECK (public.is_owner_or_admin(auth.uid()));
CREATE POLICY "courier update assigned orders" ON public.orders FOR UPDATE USING (auth.uid() = courier_id);

-- =========================================
-- ORDER_NOTES
-- =========================================
CREATE TABLE public.order_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  note text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.order_notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read order_notes" ON public.order_notes FOR SELECT TO authenticated USING (true);
CREATE POLICY "insert order_notes" ON public.order_notes FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id OR public.is_owner_or_admin(auth.uid()));
CREATE POLICY "admin manage order_notes" ON public.order_notes FOR ALL USING (public.is_owner_or_admin(auth.uid())) WITH CHECK (public.is_owner_or_admin(auth.uid()));

-- =========================================
-- MESSAGES (chat)
-- =========================================
CREATE TABLE public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  message text NOT NULL,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read own messages" ON public.messages FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id OR public.is_owner_or_admin(auth.uid()));
CREATE POLICY "send messages" ON public.messages FOR INSERT WITH CHECK (auth.uid() = sender_id);
CREATE POLICY "update own messages" ON public.messages FOR UPDATE USING (auth.uid() = receiver_id OR auth.uid() = sender_id);

-- =========================================
-- COURIER_LOCATIONS
-- =========================================
CREATE TABLE public.courier_locations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  courier_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lat double precision NOT NULL,
  lng double precision NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.courier_locations ENABLE ROW LEVEL SECURITY;
CREATE INDEX idx_courier_locations_courier ON public.courier_locations(courier_id, created_at DESC);
CREATE POLICY "courier insert own location" ON public.courier_locations FOR INSERT WITH CHECK (auth.uid() = courier_id);
CREATE POLICY "read courier_locations" ON public.courier_locations FOR SELECT TO authenticated USING (auth.uid() = courier_id OR public.is_owner_or_admin(auth.uid()));

-- =========================================
-- COURIER_COLLECTIONS / BONUSES / ADVANCES
-- =========================================
CREATE TABLE public.courier_collections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  courier_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount numeric NOT NULL DEFAULT 0,
  notes text,
  collection_date date NOT NULL DEFAULT CURRENT_DATE,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.courier_collections ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read courier_collections" ON public.courier_collections FOR SELECT TO authenticated USING (auth.uid() = courier_id OR public.is_owner_or_admin(auth.uid()));
CREATE POLICY "admin manage courier_collections" ON public.courier_collections FOR ALL USING (public.is_owner_or_admin(auth.uid())) WITH CHECK (public.is_owner_or_admin(auth.uid()));

CREATE TABLE public.courier_bonuses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  courier_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount numeric NOT NULL DEFAULT 0,
  reason text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.courier_bonuses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read courier_bonuses" ON public.courier_bonuses FOR SELECT TO authenticated USING (auth.uid() = courier_id OR public.is_owner_or_admin(auth.uid()));
CREATE POLICY "admin manage courier_bonuses" ON public.courier_bonuses FOR ALL USING (public.is_owner_or_admin(auth.uid())) WITH CHECK (public.is_owner_or_admin(auth.uid()));

CREATE TABLE public.advances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount numeric NOT NULL DEFAULT 0,
  notes text,
  advance_date date NOT NULL DEFAULT CURRENT_DATE,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.advances ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read advances" ON public.advances FOR SELECT TO authenticated USING (auth.uid() = user_id OR public.is_owner_or_admin(auth.uid()));
CREATE POLICY "admin manage advances" ON public.advances FOR ALL USING (public.is_owner_or_admin(auth.uid())) WITH CHECK (public.is_owner_or_admin(auth.uid()));

-- =========================================
-- EXPENSES + CASH FLOW
-- =========================================
CREATE TABLE public.expenses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_name text NOT NULL,
  amount numeric NOT NULL DEFAULT 0,
  category text,
  notes text,
  expense_date date NOT NULL DEFAULT CURRENT_DATE,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "admin manage expenses" ON public.expenses FOR ALL USING (public.is_owner_or_admin(auth.uid())) WITH CHECK (public.is_owner_or_admin(auth.uid()));

CREATE TABLE public.cash_flow_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type text NOT NULL,
  amount numeric NOT NULL DEFAULT 0,
  description text,
  entry_date date NOT NULL DEFAULT CURRENT_DATE,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.cash_flow_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "admin manage cash_flow" ON public.cash_flow_entries FOR ALL USING (public.is_owner_or_admin(auth.uid())) WITH CHECK (public.is_owner_or_admin(auth.uid()));

-- =========================================
-- OFFICE PAYMENTS / DAILY EXPENSES / CLOSINGS
-- =========================================
CREATE TABLE public.office_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  office_id uuid NOT NULL REFERENCES public.offices(id) ON DELETE CASCADE,
  amount numeric NOT NULL DEFAULT 0,
  notes text,
  payment_date date NOT NULL DEFAULT CURRENT_DATE,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.office_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read office_payments" ON public.office_payments FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin manage office_payments" ON public.office_payments FOR ALL USING (public.is_owner_or_admin(auth.uid())) WITH CHECK (public.is_owner_or_admin(auth.uid()));

CREATE TABLE public.office_daily_expenses (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  office_id uuid NOT NULL REFERENCES public.offices(id) ON DELETE CASCADE,
  amount numeric NOT NULL DEFAULT 0,
  description text,
  expense_date date NOT NULL DEFAULT CURRENT_DATE,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.office_daily_expenses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read office_daily_expenses" ON public.office_daily_expenses FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin manage office_daily_expenses" ON public.office_daily_expenses FOR ALL USING (public.is_owner_or_admin(auth.uid())) WITH CHECK (public.is_owner_or_admin(auth.uid()));

CREATE TABLE public.office_daily_closings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  office_id uuid NOT NULL REFERENCES public.offices(id) ON DELETE CASCADE,
  closing_date date NOT NULL,
  total_collected numeric DEFAULT 0,
  total_expenses numeric DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(office_id, closing_date)
);
ALTER TABLE public.office_daily_closings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read office_daily_closings" ON public.office_daily_closings FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin manage office_daily_closings" ON public.office_daily_closings FOR ALL USING (public.is_owner_or_admin(auth.uid())) WITH CHECK (public.is_owner_or_admin(auth.uid()));

-- =========================================
-- DIARIES + DIARY_ORDERS
-- =========================================
CREATE TABLE public.diaries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  office_id uuid NOT NULL REFERENCES public.offices(id) ON DELETE CASCADE,
  diary_date date NOT NULL,
  is_archived boolean NOT NULL DEFAULT false,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.diaries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read diaries" ON public.diaries FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin manage diaries" ON public.diaries FOR ALL USING (public.is_owner_or_admin(auth.uid())) WITH CHECK (public.is_owner_or_admin(auth.uid()));

CREATE TABLE public.diary_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  diary_id uuid NOT NULL REFERENCES public.diaries(id) ON DELETE CASCADE,
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  n_column text,
  status_override text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(diary_id, order_id)
);
ALTER TABLE public.diary_orders ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read diary_orders" ON public.diary_orders FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin manage diary_orders" ON public.diary_orders FOR ALL USING (public.is_owner_or_admin(auth.uid())) WITH CHECK (public.is_owner_or_admin(auth.uid()));

-- =========================================
-- COMPANIES + COMPANY_PAYMENTS
-- =========================================
CREATE TABLE public.companies (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  contact_name text,
  phone text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.companies ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read companies" ON public.companies FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin manage companies" ON public.companies FOR ALL USING (public.is_owner_or_admin(auth.uid())) WITH CHECK (public.is_owner_or_admin(auth.uid()));

CREATE TABLE public.company_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.companies(id) ON DELETE CASCADE,
  amount numeric NOT NULL DEFAULT 0,
  notes text,
  payment_date date NOT NULL DEFAULT CURRENT_DATE,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.company_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read company_payments" ON public.company_payments FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin manage company_payments" ON public.company_payments FOR ALL USING (public.is_owner_or_admin(auth.uid())) WITH CHECK (public.is_owner_or_admin(auth.uid()));

-- =========================================
-- ACTIVITY_LOGS
-- =========================================
CREATE TABLE public.activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  user_name text,
  action text NOT NULL,
  details jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;
CREATE INDEX idx_activity_logs_created ON public.activity_logs(created_at DESC);
CREATE POLICY "read activity_logs admin" ON public.activity_logs FOR SELECT USING (public.is_owner_or_admin(auth.uid()));
CREATE POLICY "insert activity_logs" ON public.activity_logs FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- =========================================
-- APP_SETTINGS (key/value)
-- =========================================
CREATE TABLE public.app_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  key text NOT NULL UNIQUE,
  value jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "read app_settings" ON public.app_settings FOR SELECT TO authenticated USING (true);
CREATE POLICY "admin manage app_settings" ON public.app_settings FOR ALL USING (public.is_owner_or_admin(auth.uid())) WITH CHECK (public.is_owner_or_admin(auth.uid()));

-- =========================================
-- updated_at trigger function
-- =========================================
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

CREATE TRIGGER trg_profiles_updated BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_offices_updated BEFORE UPDATE ON public.offices FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_orders_updated BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- =========================================
-- log_activity RPC (used by activityLogger.ts)
-- =========================================
CREATE OR REPLACE FUNCTION public.log_activity(action_text text, details_json jsonb DEFAULT NULL)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  uname text;
BEGIN
  SELECT full_name INTO uname FROM public.profiles WHERE user_id = auth.uid();
  INSERT INTO public.activity_logs (user_id, user_name, action, details)
  VALUES (auth.uid(), uname, action_text, details_json);
END;
$$;

-- =========================================
-- OWNER USER: tiger_owner@thepilito.ship  (password 01278006248)
-- =========================================
DO $$
DECLARE
  owner_uid uuid;
  hashed text;
BEGIN
  -- create the user via auth schema (encrypted_password using crypt+gen_salt)
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE email = 'tiger_owner@thepilito.ship') THEN
    owner_uid := gen_random_uuid();
    INSERT INTO auth.users (
      id, instance_id, aud, role, email, encrypted_password,
      email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
      is_super_admin, confirmation_token, recovery_token, email_change_token_new, email_change
    ) VALUES (
      owner_uid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
      'tiger_owner@thepilito.ship', crypt('01278006248', gen_salt('bf')),
      now(), now(), now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"full_name":"المالك"}'::jsonb,
      false, '', '', '', ''
    );
    INSERT INTO auth.identities (id, user_id, identity_data, provider, provider_id, created_at, updated_at, last_sign_in_at)
    VALUES (gen_random_uuid(), owner_uid, jsonb_build_object('sub', owner_uid::text, 'email', 'tiger_owner@thepilito.ship'),
            'email', owner_uid::text, now(), now(), now());
  ELSE
    SELECT id INTO owner_uid FROM auth.users WHERE email = 'tiger_owner@thepilito.ship';
  END IF;

  -- profile
  INSERT INTO public.profiles (user_id, full_name, email)
  VALUES (owner_uid, 'المالك', 'tiger_owner@thepilito.ship')
  ON CONFLICT (user_id) DO NOTHING;

  -- owner role
  INSERT INTO public.user_roles (user_id, role) VALUES (owner_uid, 'owner')
  ON CONFLICT (user_id, role) DO NOTHING;
END $$;
