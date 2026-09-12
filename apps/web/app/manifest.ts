import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Matricia",
    short_name: "Matricia",
    description: "Plateforme numérique de services professionnels au Maroc.",
    start_url: "/fr/connexion",
    display: "standalone",
    background_color: "#f6f8fb",
    theme_color: "#123a63",
    icons: [{ src: "/favicon.svg", sizes: "any", type: "image/svg+xml", purpose: "any" }],
  };
}
