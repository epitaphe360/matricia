-- Additive compatibility hardening for pre-hierarchy catalogue clients.

create or replace function public.decide_catalog_change(
 p_change_request_id uuid,p_approved boolean,p_comment text,p_expected_row_version integer,
 p_idempotency_key text,p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog as $$
begin
 if p_approved is null then raise exception 'INVALID_CATALOG_DECISION' using errcode='22023';end if;
 -- Preserve the legacy MFA error contract and reject unauthorized callers before
 -- the v2 function can reveal whether the requested change exists.
 perform private.assert_catalog_central_aal2_locked(auth.uid());
 return public.decide_catalog_change(p_change_request_id,case when p_approved then 'APPROVE' else 'REJECT' end,p_comment,p_expected_row_version,p_idempotency_key,p_correlation_id);
end$$;

create or replace function public.revoke_catalog_library_mandate(
 p_mandate_id uuid,p_expected_row_version integer,p_reason text,p_idempotency_key text,
 p_correlation_id uuid default extensions.gen_random_uuid()
) returns jsonb language plpgsql security definer set search_path=pg_catalog,extensions,private as $$
declare v_actor uuid:=auth.uid();v_mandate public.catalog_library_mandates%rowtype;v_hash text;v_command uuid;v_replay jsonb;v_response jsonb;
begin
 if p_mandate_id is null or p_expected_row_version is null or p_expected_row_version<1 or length(btrim(coalesce(p_reason,''))) not between 3 and 500 then
  raise exception 'INVALID_CATALOG_MANDATE_REVOCATION' using errcode='22023';
 end if;
 begin perform private.assert_catalog_central_aal2_locked(v_actor);
 exception when insufficient_privilege then raise exception 'CATALOG_MANDATE_REVOKE_DENIED' using errcode='42501';end;
 select * into v_mandate from public.catalog_library_mandates where id=p_mandate_id;
 if not found then raise exception 'CATALOG_MANDATE_NOT_FOUND' using errcode='P0002';end if;
 begin perform private.assert_catalog_permission_locked(v_mandate.library_id,'CATALOG_APPROVE',v_actor);
 exception when insufficient_privilege then raise exception 'CATALOG_MANDATE_REVOKE_DENIED' using errcode='42501';end;
 v_hash:=private.canonical_request_hash(jsonb_build_object('operation','catalog.mandate.revoke.v1','mandate_id',p_mandate_id,'expected',p_expected_row_version,'reason',btrim(p_reason)));
 select b.command_id,b.response_body into v_command,v_replay from private.begin_catalog_command(v_actor,'catalog.mandate.revoke',p_idempotency_key,v_hash)b;
 perform pg_advisory_xact_lock(hashtextextended('catalog-mandate:'||p_mandate_id::text,0));
 select * into v_mandate from public.catalog_library_mandates where id=p_mandate_id for update;
 begin perform private.assert_catalog_central_aal2_locked(v_actor);
 exception when insufficient_privilege then raise exception 'CATALOG_MANDATE_REVOKE_DENIED' using errcode='42501';end;
 begin perform private.assert_catalog_permission_locked(v_mandate.library_id,'CATALOG_APPROVE',v_actor);
 exception when insufficient_privilege then raise exception 'CATALOG_MANDATE_REVOKE_DENIED' using errcode='42501';end;
 if v_replay is not null then return v_replay;end if;
 if v_mandate.row_version is distinct from p_expected_row_version or v_mandate.status is distinct from 'ACTIVE' then raise exception 'STALE_CATALOG_VERSION' using errcode='40001';end if;
 insert into private.catalog_acl_write_capabilities(backend_pid,transaction_id) values(pg_backend_pid(),txid_current()) on conflict do nothing;
 update public.catalog_library_mandates set status='REVOKED',valid_until=coalesce(valid_until,clock_timestamp()),row_version=row_version+1 where id=p_mandate_id;
 delete from private.catalog_acl_write_capabilities where backend_pid=pg_backend_pid() and transaction_id=txid_current();
 v_response:=jsonb_build_object('outcome','CATALOG_MANDATE_REVOKED','mandate_id',p_mandate_id,'row_version',p_expected_row_version+1,'command_id',v_command);
 insert into public.audit_events(organization_id,actor_user_id,actor_type,action,resource_type,resource_id,correlation_id,metadata,previous_hash,event_hash)
 values(v_mandate.organization_id,v_actor,'USER','catalog.mandate.revoked','catalog_library_mandate',p_mandate_id::text,p_correlation_id,jsonb_build_object('reason',btrim(p_reason),'policy_version',v_mandate.policy_version,'command_id',v_command),null,repeat('0',64));
 insert into public.event_outbox(organization_id,aggregate_type,aggregate_id,event_type,correlation_id,payload,idempotency_key,causation_id)
 values(v_mandate.organization_id,'catalog_library_mandate',p_mandate_id::text,'CatalogLibraryMandateRevokedV1',p_correlation_id,jsonb_build_object('mandate_id',p_mandate_id,'library_id',v_mandate.library_id),p_idempotency_key,v_command);
 perform private.finish_catalog_command(v_actor,'catalog.mandate.revoke',p_idempotency_key,v_response);return v_response;
end$$;

revoke all on function public.decide_catalog_change(uuid,boolean,text,integer,text,uuid),public.revoke_catalog_library_mandate(uuid,integer,text,text,uuid) from public,anon,service_role;
grant execute on function public.decide_catalog_change(uuid,boolean,text,integer,text,uuid),public.revoke_catalog_library_mandate(uuid,integer,text,text,uuid) to authenticated;
