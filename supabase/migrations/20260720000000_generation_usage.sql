create extension if not exists pgcrypto;

create table if not exists public.subscriptions (
  user_id uuid primary key references auth.users (id) on delete cascade,
  plan text not null default 'free' check (plan in ('free', 'pro')),
  status text not null default 'active' check (status in ('active', 'trialing', 'past_due', 'canceled', 'expired')),
  provider text check (provider in ('stripe', 'revenuecat')),
  provider_customer_id text,
  current_period_ends_at timestamptz,
  updated_at timestamptz not null default now()
);

create table if not exists public.generation_reservations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  mode text not null check (mode in ('work_specification', 'sprint_plan', 'executive_brief')),
  character_count integer not null check (character_count > 0),
  status text not null check (status in ('reserved', 'completed', 'released')),
  created_at timestamptz not null default now(),
  finalized_at timestamptz
);

create index if not exists generation_reservations_user_created_idx
  on public.generation_reservations (user_id, created_at desc)
  where status in ('reserved', 'completed');

alter table public.subscriptions enable row level security;
alter table public.generation_reservations enable row level security;

create policy "Users can view their own subscription"
  on public.subscriptions for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can view their own generation history"
  on public.generation_reservations for select
  to authenticated
  using ((select auth.uid()) = user_id);

create or replace function public.create_default_subscription()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.subscriptions (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.create_default_subscription();

create or replace function public.consume_generation_quota(
  p_user_id uuid,
  p_requested_mode text,
  p_character_count integer
)
returns jsonb
language plpgsql
security definer set search_path = public
as $$
declare
  v_plan text := 'free';
  v_status text := 'active';
  v_is_pro boolean := false;
  v_limit integer;
  v_character_limit integer;
  v_window_start timestamptz;
  v_reset_at timestamptz;
  v_used integer;
  v_oldest_usage timestamptz;
  v_reservation_id uuid;
begin
  if p_requested_mode not in ('work_specification', 'sprint_plan', 'executive_brief') then
    raise exception 'Unsupported generation mode';
  end if;
  if p_character_count <= 0 then
    raise exception 'Character count must be positive';
  end if;

  -- Serializes allowance decisions per user while allowing other users to run
  -- independently. This prevents concurrent browser/mobile requests overspending.
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0));

  insert into public.subscriptions (user_id)
  values (p_user_id)
  on conflict (user_id) do nothing;

  select plan, status
    into v_plan, v_status
    from public.subscriptions
   where user_id = p_user_id
   for update;

  v_is_pro := v_plan = 'pro' and v_status in ('active', 'trialing');
  v_limit := case when v_is_pro then 500 else 3 end;
  v_character_limit := case when v_is_pro then 100000 else 12000 end;

  if p_character_count > v_character_limit then
    return jsonb_build_object(
      'allowed', false,
      'remaining', null,
      'plan', case when v_is_pro then 'pro' else 'free' end,
      'reset_at', null,
      'reservation_id', null
    );
  end if;

  if not v_is_pro and p_requested_mode <> 'work_specification' then
    return jsonb_build_object(
      'allowed', false,
      'remaining', null,
      'plan', 'free',
      'reset_at', null,
      'reservation_id', null
    );
  end if;

  if v_is_pro then
    v_window_start := date_trunc('month', now());
    v_reset_at := v_window_start + interval '1 month';
  else
    v_window_start := now() - interval '24 hours';
  end if;

  select count(*), min(created_at)
    into v_used, v_oldest_usage
    from public.generation_reservations
   where user_id = p_user_id
     and status in ('reserved', 'completed')
     and created_at >= v_window_start;

  if not v_is_pro and v_oldest_usage is not null then
    v_reset_at := v_oldest_usage + interval '24 hours';
  end if;

  if v_used >= v_limit then
    return jsonb_build_object(
      'allowed', false,
      'remaining', 0,
      'plan', case when v_is_pro then 'pro' else 'free' end,
      'reset_at', v_reset_at,
      'reservation_id', null
    );
  end if;

  insert into public.generation_reservations (user_id, mode, character_count, status)
  values (p_user_id, p_requested_mode, p_character_count, 'reserved')
  returning id into v_reservation_id;

  return jsonb_build_object(
    'allowed', true,
    'remaining', v_limit - v_used - 1,
    'plan', case when v_is_pro then 'pro' else 'free' end,
    'reset_at', v_reset_at,
    'reservation_id', v_reservation_id
  );
end;
$$;

create or replace function public.finalize_generation_quota(p_reservation_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update public.generation_reservations
     set status = 'completed', finalized_at = now()
   where id = p_reservation_id
     and status = 'reserved';

  if not found then
    raise exception 'Generation reservation is not active';
  end if;
end;
$$;

create or replace function public.release_generation_quota(p_reservation_id uuid)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
  update public.generation_reservations
     set status = 'released', finalized_at = now()
   where id = p_reservation_id
     and status = 'reserved';
end;
$$;

revoke all on function public.consume_generation_quota(uuid, text, integer) from public, anon, authenticated;
revoke all on function public.finalize_generation_quota(uuid) from public, anon, authenticated;
revoke all on function public.release_generation_quota(uuid) from public, anon, authenticated;
grant execute on function public.consume_generation_quota(uuid, text, integer) to service_role;
grant execute on function public.finalize_generation_quota(uuid) to service_role;
grant execute on function public.release_generation_quota(uuid) to service_role;

-- Custom function to check if a user with a given email already exists
create or replace function public.check_user_exists(p_email text)
returns boolean
language plpgsql
security definer set search_path = auth, public
as $$
declare
  v_exists boolean := false;
begin
  select exists(
    select 1 from auth.users where email = p_email
  ) into v_exists;
  return v_exists;
end;
$$;

grant execute on function public.check_user_exists(text) to anon, authenticated;
