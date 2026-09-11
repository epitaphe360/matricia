import { getSupabaseServerClient } from "@/lib/supabase/server";
import { createCatalogBuilderRepository } from "./repository";

export async function createServerCatalogBuilderRepository() {
  const client = await getSupabaseServerClient();
  return createCatalogBuilderRepository({
    async authenticated() {
      const { data, error } = await client.auth.getUser();
      return !error && Boolean(data.user);
    },
    async libraries() {
      return client.from("catalog_libraries").select("id,code,status,row_version,current_release_id").order("code").limit(10);
    },
    async library(libraryId) {
      return client.from("catalog_libraries").select("id,code,status,row_version,current_release_id").eq("id", libraryId).limit(1);
    },
    async services(libraryId) {
      return client.from("catalog_services").select("id,library_id,code,slug,status").eq("library_id", libraryId).order("code").limit(201);
    },
    async rpc(name, input) {
      return client.rpc(name, input);
    },
  });
}
