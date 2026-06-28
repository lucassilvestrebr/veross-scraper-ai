-- ═══════════════════════════════════════════════════════════════════════
--  Veross Scraper AI — Admin Setup
--  Execute no SQL Editor do Supabase APÓS o setup.sql principal
-- ═══════════════════════════════════════════════════════════════════════

-- 1. Adicionar coluna is_admin à tabela profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Função auxiliar: verifica se usuário logado é admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN LANGUAGE SQL SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE((SELECT is_admin FROM public.profiles WHERE id = auth.uid()), FALSE);
$$;

-- 3. RLS: admins leem e atualizam TODOS os perfis
DROP POLICY IF EXISTS "admin_select_all_profiles" ON public.profiles;
DROP POLICY IF EXISTS "admin_update_all_profiles" ON public.profiles;
CREATE POLICY "admin_select_all_profiles" ON public.profiles
  FOR SELECT USING (public.is_admin());
CREATE POLICY "admin_update_all_profiles" ON public.profiles
  FOR UPDATE USING (public.is_admin());

-- 4. RLS: admins leem e atualizam TODAS as solicitações
DROP POLICY IF EXISTS "admin_select_all_requests" ON public.scraping_requests;
DROP POLICY IF EXISTS "admin_update_all_requests" ON public.scraping_requests;
CREATE POLICY "admin_select_all_requests" ON public.scraping_requests
  FOR SELECT USING (public.is_admin());
CREATE POLICY "admin_update_all_requests" ON public.scraping_requests
  FOR UPDATE USING (public.is_admin());

-- 5. Função RPC: retorna todos os usuários com email (para o painel admin)
CREATE OR REPLACE FUNCTION public.admin_get_users()
RETURNS TABLE(
  id         UUID,
  email      TEXT,
  first_name TEXT,
  last_name  TEXT,
  company    TEXT,
  credits    INTEGER,
  is_admin   BOOLEAN,
  created_at TIMESTAMPTZ
)
LANGUAGE SQL SECURITY DEFINER SET search_path = public AS $$
  SELECT
    p.id, u.email,
    p.first_name, p.last_name, p.company,
    p.credits, p.is_admin, p.created_at
  FROM public.profiles p
  JOIN auth.users u ON u.id = p.id
  WHERE (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = TRUE
  ORDER BY p.created_at;
$$;

-- 6. Definir o admin (troque o e-mail se necessário)
UPDATE public.profiles
SET is_admin = TRUE
WHERE id = (
  SELECT id FROM auth.users
  WHERE email = 'lucas.silvestre@veross.com.br'
);

-- 7. Verificação final
SELECT p.id, u.email, p.first_name, p.credits, p.is_admin
FROM public.profiles p
JOIN auth.users u ON u.id = p.id
ORDER BY p.is_admin DESC, p.created_at;
