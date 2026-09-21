export function PublicPathArt({
  caption,
  signs,
}: {
  caption: string;
  signs: readonly [string, string, string];
}) {
  return (
    <figure className="public-path-art" aria-hidden="true">
      <svg viewBox="0 0 640 400" role="img">
        <title>{caption}</title>
        <path d="M0 268c90-38 150-18 250-28 92-8 140 34 230 18 70-12 110-40 160-28v170H0Z" fill="#efe4d2" />
        <path d="M0 300c110-42 190-8 300-22 96-12 150 28 236 12 58-10 78-28 104-18v128H0Z" fill="#e7d6be" />
        <path d="M0 332c80-18 170 6 280-8 90-12 140 16 220 4 62-8 90-22 140-10v82H0Z" fill="#f3e6d2" />
        <path d="M48 338c70-54 130-118 196-132 58-12 92 22 150 10 62-14 108-62 198-48" fill="none" stroke="#ead7bd" strokeWidth="22" strokeLinecap="round" />
        <path d="M56 340c68-52 126-112 190-126 56-12 90 20 146 10 60-12 110-58 196-46" fill="none" stroke="#f7f0e4" strokeWidth="10" strokeLinecap="round" />
        <circle cx="438" cy="78" r="42" fill="#f3c4a4" />
        <path d="M392 196c46-78 128-78 174 0v78H392Z" fill="#ead9c4" />
        <path d="M408 196c36-58 106-58 142 0v18H408Z" fill="#ddc7ab" />
        <ellipse cx="479" cy="196" rx="28" ry="10" fill="#d7c0a4" />
        <g fill="#5f7358">
          <path d="M118 318c-10-78-2-128 8-168 14 42 22 96-8 168Z" />
          <path d="M156 326c-8-64 2-108 10-142 10 36 14 84-10 142Z" />
          <path d="M214 330c-7-58 4-96 12-128 8 34 12 76-12 128Z" />
          <path d="M548 328c8-72 2-118-8-154-12 38-8 90 8 154Z" />
          <path d="M586 334c6-56 0-96-8-128 10 32 12 78 8 128Z" />
        </g>
        <path d="M92 318c18-28 40-28 58 0  -10 8-20 14-29 14s-19-6-29-14Z" fill="#6d7f62" />
        <path d="M188 324c14-22 32-22 46 0-8 6-16 11-23 11s-15-5-23-11Z" fill="#7f9170" />
        <path d="M520 322c16-24 36-24 52 0-9 7-18 12-26 12s-17-5-26-12Z" fill="#6d7f62" />
        <rect x="286" y="214" width="9" height="96" rx="2" fill="#1a2744" />
        <path d="M295 218h118l-16 22H295Z" fill="#1a2744" />
        <path d="M295 248h104l-16 22H295Z" fill="#1a2744" />
        <path d="M295 278h90l-16 22H295Z" fill="#1a2744" />
        <text x="308" y="234" fill="#fff" fontSize="12" fontWeight="700">{signs[0]}</text>
        <text x="308" y="264" fill="#fff" fontSize="12" fontWeight="700">{signs[1]}</text>
        <text x="308" y="294" fill="#fff" fontSize="12" fontWeight="700">{signs[2]}</text>
      </svg>
      <figcaption className="journey-script">{caption}</figcaption>
    </figure>
  );
}

export function PublicRibbon() {
  return (
    <svg className="public-ribbon" viewBox="0 0 72 88" width="72" height="88" aria-hidden="true">
      <path d="M12 8h48l-6 44H18Z" fill="#6d3cc7" />
      <path d="M18 52 8 84l16-12 12 16 12-16 16 12-10-32Z" fill="#c4a574" />
      <circle cx="36" cy="34" r="14" fill="#fff" />
      <path d="m30 34 4 4 8-9" fill="none" stroke="#6d3cc7" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}
