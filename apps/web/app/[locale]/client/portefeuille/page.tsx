import { randomUUID } from "node:crypto";
import { notFound, redirect } from "next/navigation";
import { isLocale } from "@/lib/i18n/locale";
import { loadClientPortfolio } from "@/lib/client-portfolio/server-repository";
import { PortfolioPanel } from "./portfolio-panel";
import { getMessages } from "./messages";

export default async function Page({params,searchParams}:{params:Promise<{locale:string}>;searchParams:Promise<{organizationId?:string}>}){const{locale}=await params,{organizationId}=await searchParams;if(!isLocale(locale))notFound();const result=await loadClientPortfolio(organizationId);if(result.status==="error"&&result.reason==="UNAUTHENTICATED")redirect(`/${locale}/connexion`);if(result.status==="error")throw new Error("CLIENT_PORTFOLIO_UNAVAILABLE");return <PortfolioPanel locale={locale} data={result.value} m={getMessages(locale)} keys={{project:randomUUID(),task:randomUUID(),contract:randomUUID(),budget:randomUUID(),center:randomUUID(),allocation:randomUUID(),event:randomUUID()}}/>;}
