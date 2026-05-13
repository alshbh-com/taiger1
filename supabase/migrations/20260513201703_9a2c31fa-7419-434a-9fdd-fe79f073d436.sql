
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS login_code text;

-- Update owner email to match auth-login codeToEmail format
DO $$
DECLARE
  owner_uid uuid;
BEGIN
  SELECT id INTO owner_uid FROM auth.users WHERE email = 'tiger_owner@thepilito.ship';
  IF owner_uid IS NOT NULL THEN
    UPDATE auth.users
    SET email = '01278006248@thepilito.ship',
        encrypted_password = crypt('01278006248', gen_salt('bf'))
    WHERE id = owner_uid;
    UPDATE auth.identities
    SET identity_data = jsonb_build_object('sub', owner_uid::text, 'email', '01278006248@thepilito.ship'),
        provider_id = '01278006248@thepilito.ship'
    WHERE user_id = owner_uid AND provider = 'email';
    UPDATE public.profiles SET login_code = '01278006248', email = '01278006248@thepilito.ship' WHERE user_id = owner_uid;
  END IF;
END $$;
