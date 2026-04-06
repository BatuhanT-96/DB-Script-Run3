-- This file is intentionally unsafe for Prod validation demonstration.
DELETE FROM public.dispatcher_test_table WHERE created_at < NOW() - INTERVAL '30 days';
