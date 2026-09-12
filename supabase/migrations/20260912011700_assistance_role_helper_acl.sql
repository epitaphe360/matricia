-- RLS must be able to execute the least-privilege predicate as the authenticated caller.
revoke all on function private.assistance_role_access(uuid,text,uuid)from public,anon,authenticated,service_role;
grant execute on function private.assistance_role_access(uuid,text,uuid)to authenticated;
