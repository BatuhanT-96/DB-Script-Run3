-- Safe Postgre DML for Test
UPDATE public.customer_profile
SET status = 'ACTIVE', updated_at = NOW()
WHERE customer_id = 1001;

INSERT INTO public.audit_log (entity_name, action_name, created_at)
VALUES ('customer_profile', 'status_update', NOW());
