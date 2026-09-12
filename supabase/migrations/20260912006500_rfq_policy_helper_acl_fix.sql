-- Additive repair for development environments where migration 059 was already applied.
revoke all on function
  private.can_manage_client_request(uuid,uuid),
  private.is_provider_actor(uuid,uuid),
  private.can_read_service_request(uuid,uuid)
from public,anon,authenticated,service_role;

grant execute on function
  private.can_manage_client_request(uuid,uuid),
  private.is_provider_actor(uuid,uuid),
  private.can_read_service_request(uuid,uuid)
to authenticated;
