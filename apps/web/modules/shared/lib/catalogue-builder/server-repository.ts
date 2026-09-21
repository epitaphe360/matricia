import { getSupabaseServerClient } from "@/modules/shared/lib/supabase/server";
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
    async draftReleases(libraryId) {
      return client.from("catalog_releases").select("id,library_id,release_key,row_version,status").eq("library_id", libraryId).eq("status", "DRAFT").order("created_at", { ascending: false }).limit(100);
    },
    async approvedServiceVersions(libraryId) {
      return client.from("catalog_service_versions").select("id,service_id,library_id,version,status,name_fr,name_ar").eq("library_id", libraryId).eq("status", "APPROVED").order("version", { ascending: false }).limit(500);
    },
    async release(releaseId) {
      return client.from("catalog_releases").select("id,library_id,row_version,status").eq("id", releaseId).limit(1);
    },
    async serviceVersion(versionId) {
      return client.from("catalog_service_versions").select("id,service_id,library_id,content_hash,status").eq("id", versionId).limit(1);
    },
    async lastReleaseItem(releaseId) {
      return client.from("catalog_release_items").select("sort_order").eq("release_id", releaseId).order("sort_order", { ascending: false }).limit(1);
    },
    async rpc(name, input) {
      return client.rpc(name, input);
    },
  });
}
