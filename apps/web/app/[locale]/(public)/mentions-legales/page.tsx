import { createLegalPage } from "@/modules/public/data/legal/page-factory";

const page = createLegalPage("mentions");
export const generateMetadata = page.generateMetadata;
export default page.Page;
