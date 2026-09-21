import { createLegalPage } from "@/modules/public/data/legal/page-factory";

const page = createLegalPage("confidentialite");
export const generateMetadata = page.generateMetadata;
export default page.Page;
