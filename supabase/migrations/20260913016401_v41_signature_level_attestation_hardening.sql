-- Additive reconciliation after 16400: every signer must attest the exact
-- requested level before an envelope may truthfully become SIGNED.
alter table public.signature_signers
  add column achieved_level text check(achieved_level in('SIMPLE','ADVANCED','QUALIFIED'));

alter table public.signature_signers
  add constraint signature_signers_achieved_level_state_check
  check((status='SIGNED' and achieved_level is not null)or(status<>'SIGNED'and achieved_level is null));

create function private.enforce_signature_signer_level_attestation()returns trigger
language plpgsql set search_path=pg_catalog
as $$begin
  if tg_op='UPDATE'and old.status='SIGNED'and(new.status,new.identity_verification_level,new.achieved_level,new.signed_at)is distinct from(old.status,old.identity_verification_level,old.achieved_level,old.signed_at)then raise exception'IMMUTABLE_SIGNED_SIGNER'using errcode='55000';end if;
  if new.status='SIGNED'then
    new.achieved_level:=coalesce(new.achieved_level,case new.identity_verification_level when'QUALIFIED'then'QUALIFIED'when'STRONG'then'ADVANCED'when'BASIC'then'SIMPLE'else null end);
    if new.achieved_level is null or new.identity_verification_level is distinct from(case new.achieved_level when'QUALIFIED'then'QUALIFIED'when'ADVANCED'then'STRONG'else'BASIC'end)then raise exception'SIGNATURE_LEVEL_ATTESTATION_MISMATCH'using errcode='23514';end if;
  elsif new.achieved_level is not null then raise exception'SIGNATURE_LEVEL_BEFORE_SIGNING'using errcode='23514';end if;
  return new;
end$$;

create trigger signature_signer_level_attestation before insert or update on public.signature_signers for each row execute function private.enforce_signature_signer_level_attestation();

create function private.enforce_signature_envelope_level_honesty()returns trigger
language plpgsql security definer set search_path=pg_catalog,public
as $$begin
  if new.status='SIGNED'and old.status is distinct from'SIGNED'then
    if new.achieved_level is distinct from new.requested_level
      or not exists(select 1 from public.signature_provider_configs c where c.id=new.provider_config_id and new.achieved_level=any(c.supported_levels))
      or exists(select 1 from public.signature_signers s where s.envelope_id=new.id and(s.status<>'SIGNED'or s.achieved_level is distinct from new.requested_level))
      or not exists(select 1 from public.signature_signers s where s.envelope_id=new.id)
    then raise exception'QUALIFIED_LEVEL_NOT_ACHIEVED'using errcode='23514';end if;
  end if;
  return new;
end$$;

create trigger signature_envelope_level_honesty before update on public.signature_envelopes for each row execute function private.enforce_signature_envelope_level_honesty();

revoke all on function private.enforce_signature_signer_level_attestation(),private.enforce_signature_envelope_level_honesty()from public,anon,authenticated,service_role;
