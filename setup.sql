-- ═══════════════════════════════════════════════════════════════════════
--  Veross Scraper AI — Configuração do Banco de Dados (Supabase)
--  Execute este arquivo no SQL Editor do Supabase Dashboard
--  Supabase Dashboard → SQL Editor → New query → Cole e execute
-- ═══════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────
-- 1. TABELA: profiles  (estende auth.users)
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id           UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  first_name   TEXT NOT NULL DEFAULT '',
  last_name    TEXT NOT NULL DEFAULT '',
  company      TEXT          DEFAULT '',
  whatsapp     TEXT          DEFAULT '',
  credits      INTEGER NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ   DEFAULT NOW(),
  updated_at   TIMESTAMPTZ   DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────
-- 2. TABELA: scraping_requests
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.scraping_requests (
  id                UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id           UUID        REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  display_name      TEXT        NOT NULL,
  status            TEXT        NOT NULL DEFAULT 'processing'
                                CHECK (status IN ('processing','queued','scraping','completed','error')),
  requested_qty     INTEGER     NOT NULL DEFAULT 400,
  extracted_qty     INTEGER,
  credits_used      INTEGER,
  file_url          TEXT,
  -- Filtros
  email_verified    BOOLEAN     DEFAULT TRUE,
  employees         TEXT        DEFAULT '',
  "current_role"      TEXT        DEFAULT '',
  prev_role         TEXT        DEFAULT '',
  exclude_role      TEXT        DEFAULT '',
  function_area     TEXT        DEFAULT '',
  include_company   TEXT        DEFAULT '',
  exclude_company   TEXT        DEFAULT '',
  location          TEXT        DEFAULT '',
  exclude_location  TEXT        DEFAULT '',
  sector            TEXT        DEFAULT '',
  exclude_sector    TEXT        DEFAULT '',
  search_in         TEXT        DEFAULT '',
  -- Metadados de integração
  n8n_execution_id  TEXT,
  webhook_sent_at   TIMESTAMPTZ,
  notes             TEXT,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────
-- 3. ROW LEVEL SECURITY (RLS)
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE public.profiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scraping_requests ENABLE ROW LEVEL SECURITY;

-- profiles: cada usuário acessa apenas o próprio perfil
CREATE POLICY "profiles_select_own" ON public.profiles
  FOR SELECT USING (auth.uid() = id);
CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- scraping_requests: cada usuário vê e cria apenas as próprias solicitações
CREATE POLICY "requests_select_own" ON public.scraping_requests
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "requests_insert_own" ON public.scraping_requests
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- NOTA: o n8n usa service_role key (bypassa RLS por padrão)
-- e pode atualizar qualquer linha sem política adicional.

-- ─────────────────────────────────────────────────────────────────────
-- 4. TRIGGER: criar perfil automaticamente ao registrar usuário
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.profiles (id, first_name, last_name, company, whatsapp)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'first_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'last_name',  ''),
    COALESCE(NEW.raw_user_meta_data->>'company',    ''),
    COALESCE(NEW.raw_user_meta_data->>'whatsapp',   '')
  );
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ─────────────────────────────────────────────────────────────────────
-- 5. TRIGGER: atualizar updated_at automaticamente
-- ─────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE TRIGGER requests_updated_at
  BEFORE UPDATE ON public.scraping_requests
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ─────────────────────────────────────────────────────────────────────
-- 6. ÍNDICES DE PERFORMANCE
-- ─────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_requests_user_id   ON public.scraping_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_requests_status    ON public.scraping_requests(status);
CREATE INDEX IF NOT EXISTS idx_requests_created   ON public.scraping_requests(created_at DESC);

-- ═══════════════════════════════════════════════════════════════════════
--  COMO O N8N DEVE ATUALIZAR AS SOLICITAÇÕES
-- ═══════════════════════════════════════════════════════════════════════
--
--  Use a service_role key (Dashboard → Settings → API → service_role)
--  Endpoint: PATCH https://itpoitqoeeqggetrfkro.supabase.co/rest/v1/scraping_requests?id=eq.<request_id>
--  Headers:
--    apikey: <service_role_key>
--    Authorization: Bearer <service_role_key>
--    Content-Type: application/json
--    Prefer: return=minimal
--
--  Body (exemplo de conclusão):
--  {
--    "status": "completed",
--    "extracted_qty": 452,
--    "file_url": "https://drive.google.com/...",
--    "credits_used": 452,
--    "n8n_execution_id": "exec-abc123"
--  }
--
--  Status possíveis que o n8n pode setar:
--    processing → queued → scraping → completed
--                                   → error  (em caso de falha)
--
-- ═══════════════════════════════════════════════════════════════════════
--  ADICIONAR CRÉDITOS A UM USUÁRIO (via Dashboard → SQL Editor)
-- ═══════════════════════════════════════════════════════════════════════
--
--  UPDATE public.profiles
--  SET credits = credits + 1000
--  WHERE id = '<user_uuid>';
--
--  (Para descobrir o UUID: Authentication → Users → clique no usuário)
--
-- ═══════════════════════════════════════════════════════════════════════
--  PÓS-EXECUÇÃO — PASSOS ADICIONAIS NO DASHBOARD
-- ═══════════════════════════════════════════════════════════════════════
--
--  1. Authentication → Settings → "Confirm email" → DESABILITAR
--     (para que o login funcione sem confirmação de e-mail)
--
--  2. Authentication → Settings → Site URL → defina a URL do projeto
--
--  3. Para habilitar atualizações em tempo real (opcional):
--     Database → Replication → scraping_requests → ligar
--
-- ═══════════════════════════════════════════════════════════════════════
