-- pgTAP is enabled only as database test support; it exposes no application data.
create extension if not exists pgtap with schema extensions;
