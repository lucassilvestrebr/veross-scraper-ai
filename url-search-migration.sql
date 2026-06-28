-- ═══════════════════════════════════════════════════════════════════════
--  Veross Scraper AI — Migração: Search URL LinkedIn + perfil linkedin
--  Execute no SQL Editor do Supabase
-- ═══════════════════════════════════════════════════════════════════════

-- 1. Adicionar coluna linkedin ao perfil
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS linkedin TEXT;

-- 2. Adicionar tipo de requisição e params de busca
ALTER TABLE public.scraping_requests
  ADD COLUMN IF NOT EXISTS request_type TEXT DEFAULT 'linkedin_bulk',
  ADD COLUMN IF NOT EXISTS search_params JSONB;

-- Verificação
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name IN ('profiles','scraping_requests')
  AND column_name IN ('linkedin','request_type','search_params')
ORDER BY table_name, column_name;
