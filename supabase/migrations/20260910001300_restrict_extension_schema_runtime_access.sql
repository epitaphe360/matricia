revoke usage on schema extensions from anon, authenticated, service_role;

comment on schema extensions is
  'Extension implementation schema. Runtime roles use reviewed public RPCs and cannot invoke extension internals directly.';
