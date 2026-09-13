-- RLS policy helpers must remain executable by the role evaluating the policy.
-- The helper is SECURITY DEFINER, fixed-search-path and only returns a boolean.
grant execute on function private.privacy_read_access(uuid,uuid) to authenticated;
