const scenes = {
  arch: "/scenes/arch-city.png",
  koutoubia: "/scenes/koutoubia-arch.png",
  window: "/scenes/window-medina.png",
  path: "/scenes/path.png",
  craftsman: "/scenes/craftsman.png",
  lantern: "/scenes/lantern-riad.png",
  zellige: "/scenes/zellige-arch.png",
  terrace: "/scenes/medina-terrace.png",
} as const;

export function PublicPhoto({
  caption,
  lead,
  scene = "arch",
  className = "",
}: {
  caption?: string;
  lead?: string;
  scene?: keyof typeof scenes;
  className?: string;
}) {
  return (
    <figure className={`public-photo ${className}`.trim()}>
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={scenes[scene]} alt="" />
      {caption || lead ? (
        <figcaption>
          {lead ? <strong>{caption}</strong> : caption}
          {lead ? <span>{lead}</span> : null}
        </figcaption>
      ) : null}
    </figure>
  );
}
