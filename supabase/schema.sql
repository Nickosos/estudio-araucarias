create extension if not exists "pgcrypto";

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null check (category in ('Preparación', 'Pintura', 'Terminación', 'Herramientas')),
  description text not null default '',
  price_clp integer not null check (price_clp >= 0),
  stock integer not null default 0 check (stock >= 0),
  color text not null default '#a9b4a6',
  tag text not null default 'PRODUCTO',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null,
  customer_email text not null,
  customer_phone text not null,
  notes text not null default '',
  payment_method text not null check (payment_method in ('mercadopago', 'transfer')),
  payment_status text not null default 'pending' check (payment_status in ('pending', 'approved', 'rejected')),
  status text not null default 'pending' check (status in ('pending', 'confirmed', 'shipped', 'completed', 'cancelled')),
  total_clp integer not null check (total_clp >= 0),
  stock_reserved boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id),
  product_name text not null,
  quantity integer not null check (quantity > 0),
  unit_price_clp integer not null check (unit_price_clp >= 0)
);

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.admin_users enable row level security;

create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (select 1 from public.admin_users where user_id = auth.uid());
$$;

drop policy if exists "Public can read active products" on public.products;
drop policy if exists "Owners manage products" on public.products;
drop policy if exists "Customers can create orders" on public.orders;
drop policy if exists "Owners can manage orders" on public.orders;
drop policy if exists "Customers can create order items" on public.order_items;
drop policy if exists "Owners can read order items" on public.order_items;

create policy "Public can read active products" on public.products
  for select using (active = true);
create policy "Owners manage products" on public.products
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "Customers can create orders" on public.orders
  for insert with check (true);
create policy "Owners can manage orders" on public.orders
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "Customers can create order items" on public.order_items
  for insert with check (true);
create policy "Owners can read order items" on public.order_items
  for select to authenticated using (public.is_admin());

create or replace function public.reserve_order_stock(p_items jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  item jsonb;
  current_stock integer;
  requested_quantity integer;
begin
  for item in select value from jsonb_array_elements(p_items)
  loop
    requested_quantity := (item->>'quantity')::integer;
    select stock into current_stock from public.products
      where id = (item->>'product_id')::uuid and active = true
      for update;
    if current_stock is null or requested_quantity < 1 or current_stock < requested_quantity then
      raise exception 'INSUFFICIENT_STOCK';
    end if;
    update public.products
      set stock = stock - requested_quantity
      where id = (item->>'product_id')::uuid;
  end loop;
end;
$$;

create or replace function public.release_order_stock(p_items jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  item jsonb;
begin
  for item in select value from jsonb_array_elements(p_items)
  loop
    update public.products
      set stock = stock + (item->>'quantity')::integer
      where id = (item->>'product_id')::uuid;
  end loop;
end;
$$;

insert into public.products (name, category, description, price_clp, stock, color, tag)
select * from (values
  ('Primer alto sólidos 2K', 'Preparación', 'Formato 1L · Gris', 18990, 10, '#a9b4a6', 'PRIMER 2K'),
  ('Barniz acrílico 2K', 'Terminación', 'Formato 1L · Alto brillo', 24990, 8, '#e3e6d4', 'CLEAR 2K'),
  ('Masilla poliéster fina', 'Preparación', 'Formato 1kg · Secado rápido', 8990, 20, '#d49a5d', 'MASILLA'),
  ('Diluyente universal', 'Pintura', 'Formato 1L · Uso profesional', 7990, 15, '#a9b5a2', 'THINNER'),
  ('Base color blanco', 'Pintura', 'Formato 1L · Excelente cubritivo', 16990, 9, '#f0eee1', 'BASE'),
  ('Lija al agua surtida', 'Herramientas', 'Pack 10 unidades', 4990, 30, '#d08d52', 'P400'),
  ('Cinta enmascarar', 'Herramientas', 'Rollo 50m · 24mm', 3990, 24, '#d8b94a', 'TAPE'),
  ('Pasta de pulir fina', 'Terminación', 'Formato 500g · Acabado espejo', 11990, 12, '#d8d9ca', 'POLISH')
) as seed(name, category, description, price_clp, stock, color, tag)
where not exists (select 1 from public.products);
