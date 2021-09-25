-- Deploy <%= projectName %>:util/upsert_timestamp_columns to pg
-- requires: trigger_function/update_timestamps

begin;

create or replace function <%= schemaName %>_private.upsert_timestamp_columns(
  table_schema_name text,
  table_name text,
  add_create boolean default true,
  add_update boolean default true,
  add_delete boolean default true, 
  user_table_schema_name text default '<%= schemaName %>',
  user_table_name text default '<%= projectName %>_user'
)
returns void as $$

declare
  column_string text;
  index_string text;
  trigger_string text;

begin

    if add_create = true then
      column_string := concat(
        'alter table ', 
        table_schema_name, '.', table_name, 
        ' add column if not exists created_by int references ', 
        user_table_schema_name, '.', user_table_name, '(id)',
        ', add column if not exists created_at timestamptz not null default now()'
      );
      execute(column_string);
      index_string := concat(
        'create index if not exists ', table_schema_name, '_', table_name, '_created_by_foreign_key on ',
        table_schema_name, '.', table_name, '(created_by)'
      );
      execute(index_string);
    end if;
    if add_update = true then
      column_string := concat(
        'alter table ', table_schema_name, '.', table_name,
        ' add column if not exists updated_by int references',
        user_table_schema_name, '.', user_table_name, '(id)',
        ', add column if not exists updated_at timestamptz not null default now()'
      );
      execute(column_string);
      index_string := concat(
        'create index if not exists ', table_schema_name, '_', table_name, '_updated_by_foreign_key on ', 
        table_schema_name, '.', table_name, '(updated_by)'
      );
      execute(index_string);
    end if;
    if add_delete = true then
      column_string := concat(
        'alter table ', table_schema_name, '.', table_name, 
        ' add column if not exists deleted_by int references',
        user_table_schema_name, '.', user_table_name, '(id)',
        ', add column if not exists deleted_at timestamptz'
      );
      execute(column_string);
      index_string := concat(
        'create index if not exists ', table_schema_name, '_', table_name, '_deleted_by_foreign_key on ', 
        table_schema_name, '.', table_name, '(deleted_by)'
      );
      execute(index_string);
    end if;

  if not exists (select *
    from information_schema.triggers
    where event_object_table = table_name
    and trigger_name = '_100_timestamps'
  ) then
    trigger_string := concat(
      'create trigger _100_timestamps before insert or update on ', table_schema_name, '.', table_name,
      ' for each row execute procedure <%= schemaName %>_private.update_timestamps()'
    );
    execute(trigger_string);
  end if;

end;
$$ language plpgsql;

comment on function <%= schemaName %>_private.upsert_timestamp_columns(text, text, boolean, boolean, boolean, text, text)
  is $$
  an internal function that adds the created/updated/deleted at/by columns, indices on fkeys and applies the _100_timestamps trigger
  example usage:

  create table some_schema.some_table (
    ...
  );
  select <%= schemaName %>_private.upsert_timestamp_columns(
  table_schema_name := 'some_schema',
  table_name := 'some_table',
  add_create := true,
  add_update := true,
  add_delete := true);
  $$;

commit;
