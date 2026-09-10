export * from "./money";

export type OrganizationId = string & { readonly __brand: "OrganizationId" };
export type BasisPoints = number & { readonly __brand: "BasisPoints" };
