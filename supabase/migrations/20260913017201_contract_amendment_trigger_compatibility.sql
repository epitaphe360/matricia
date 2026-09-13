-- Preserve the historical trigger contract while retaining lifecycle-only updates.
drop trigger amendments_lifecycle_guard on public.contract_amendments;
create trigger amendments_immutable before update or delete on public.contract_amendments for each row execute function private.guard_contract_amendment_lifecycle();
