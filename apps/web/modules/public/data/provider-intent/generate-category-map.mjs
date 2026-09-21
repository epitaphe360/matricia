import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const currentDirectory = dirname(fileURLToPath(import.meta.url));
const catalogueDirectory = join(currentDirectory, "..", "..", "..", "..", "catalogue", "Matricia_Catalogue_Metier_V1");

function parseCsv(source) {
  const parseLine = (line) => {
    const row = [];
    let field = "", quoted = false;
    for (let index = 0; index < line.length; index += 1) {
      const character = line[index];
      if (character === '"') {
        if (quoted && line[index + 1] === '"') { field += '"'; index += 1; }
        else quoted = !quoted;
      } else if (character === "," && !quoted) { row.push(field); field = ""; }
      else field += character;
    }
    row.push(field);
    return row;
  };
  const rows = source.trim().split(/\r?\n/u).map(parseLine);
  const [headers, ...values] = rows;
  return values.map((valuesRow) => Object.fromEntries(headers.map((header, index) => [header, valuesRow[index] ?? ""])));
}

const subcategories = parseCsv(readFileSync(join(catalogueDirectory, "subcategories.csv"), "utf8"));
const links = parseCsv(readFileSync(join(catalogueDirectory, "service_subcategory_links.csv"), "utf8"));
const names = new Map(subcategories.map((category) => [category.code, category.name_fr]));
const categoryMap = Object.fromEntries(links.filter((link) => link.link_type === "PRIMARY").map((link) => [link.service_code, {
  code: link.subcategory_code,
  name: names.get(link.subcategory_code) ?? link.subcategory_code,
}]));

if (Object.keys(categoryMap).length !== 200) throw new Error(`Expected 200 primary service mappings, received ${Object.keys(categoryMap).length}`);
writeFileSync(join(currentDirectory, "category-map.json"), `${JSON.stringify(categoryMap, null, 2)}\n`, "utf8");
