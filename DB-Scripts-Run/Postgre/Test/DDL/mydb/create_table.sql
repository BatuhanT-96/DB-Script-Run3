CREATE TABLE IF NOT EXISTS public.dispatcher_test_table (
    id BIGINT PRIMARY KEY,
    note TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
