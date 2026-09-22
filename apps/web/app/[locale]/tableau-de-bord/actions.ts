"use server";

import { signOutOfWorkspace } from "@/modules/shared/lib/account-security/sign-out-action";

export async function signOut(formData: FormData) {
  await signOutOfWorkspace(formData);
}
