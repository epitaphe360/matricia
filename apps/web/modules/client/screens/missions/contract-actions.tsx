"use client";

import { useActionState } from "react";
import { Button } from "@/modules/shared/ui/button";
import { Input } from "@/modules/shared/ui/input";
import { Label } from "@/modules/shared/ui/label";
import type { Locale } from "@/modules/shared/lib/i18n/locale";
import type { ContractMissionDashboard } from "@/modules/shared/lib/contracts-missions/model";
import { signContract, submitContract, type MissionActionState } from "@/modules/client/screens/missions/actions";
import type { MissionMessages } from "@/modules/client/screens/missions/messages";

const idle: MissionActionState = { status: "idle" };

function Feedback({ s, m }: { s: MissionActionState; m: MissionMessages }) {
  const x = s.status === "success" ? m.success : s.status === "error" ? (s.reason === "VALIDATION" ? m.validation : s.reason === "FORBIDDEN" ? m.forbidden : s.reason === "CONFLICT" ? m.conflict : m.failed) : "";
  return <p role={s.status === "error" ? "alert" : "status"} aria-live="polite" className={s.status === "error" ? "min-h-5 text-sm text-destructive" : "min-h-5 text-sm text-primary"}>{x}</p>;
}

export function SubmitContractForm({
  contract,
  locale,
  messages,
}: {
  contract: ContractMissionDashboard["contracts"][number];
  locale: Locale;
  messages: MissionMessages;
}) {
  const [state, action, pending] = useActionState(submitContract, idle);
  return (
    <form action={action} className="space-y-3">
      <input type="hidden" name="locale" value={locale} />
      <input type="hidden" name="idempotencyKey" value={crypto.randomUUID()} />
      <input type="hidden" name="contractId" value={contract.id} />
      <input type="hidden" name="rowVersion" value={contract.rowVersion} />
      <Button disabled={pending} className="min-h-11 w-full">{pending ? messages.pending : messages.submit}</Button>
      <Feedback s={state} m={messages} />
    </form>
  );
}

export function SignContractForm({
  contract,
  organizationId,
  locale,
  messages,
}: {
  contract: ContractMissionDashboard["contracts"][number];
  organizationId: string;
  locale: Locale;
  messages: MissionMessages;
}) {
  const [state, action, pending] = useActionState(signContract, idle);
  const proofId = `${contract.id}-proof`;
  return (
    <form action={action} className="space-y-3">
      <input type="hidden" name="locale" value={locale} />
      <input type="hidden" name="idempotencyKey" value={crypto.randomUUID()} />
      <input type="hidden" name="contractId" value={contract.id} />
      <input type="hidden" name="contractVersionId" value={contract.versionId} />
      <input type="hidden" name="organizationId" value={organizationId} />
      <input type="hidden" name="contractHash" value={contract.contentHash} />
      <input type="hidden" name="signerRole" value="CLIENT_OWNER" />
      <input type="hidden" name="method" value="EXPLICIT_CONFIRMATION" />
      <input type="hidden" name="signedAt" value={new Date().toISOString()} />
      <div className="space-y-2">
        <Label htmlFor={proofId}>{messages.evidenceHash}</Label>
        <Input id={proofId} name="evidenceHash" required pattern="[0-9a-f]{64}" minLength={64} maxLength={64} className="min-h-11" dir="ltr" />
      </div>
      <Button disabled={pending} className="min-h-11 w-full">{pending ? messages.pending : messages.sign}</Button>
      <Feedback s={state} m={messages} />
    </form>
  );
}
