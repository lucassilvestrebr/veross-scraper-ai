-- Remove trigger e função que causam o erro "pg_net does not exist"
DROP TRIGGER IF EXISTS on_new_scraping_request ON public.scraping_requests;
DROP FUNCTION IF EXISTS public.notify_n8n_scraping();

-- Confirma que não sobrou nada com pg_net
SELECT routine_name
FROM information_schema.routines
WHERE routine_definition ILIKE '%pg_net%'
   OR routine_definition ILIKE '%net.http%';
-- Se retornar vazio = resolvido
