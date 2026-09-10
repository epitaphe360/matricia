---
name: matricia-i18n-rtl-accessibility
description: Implement and audit French, Arabic RTL, localization and accessibility across Matricia workflows.
---
# I18n, RTL and accessibility
- **Scope:** FR/AR messages, formatting, directionality, semantic UI, keyboard and assistive technology.
- **Invariants:** no user-facing hardcoded copy outside localization; native RTL layout; locale-safe dates/numbers/money; critical flows meet accessibility requirements at 360 px.
- **Targeted context:** load affected route/component messages and canonical states only; catalogue translations only for the selected subset.
- **Checks:** missing keys, pluralization, bidi content, focus order/traps, labels/errors, contrast, screen reader names, zoom/reflow and automated plus manual a11y/E2E.
- **Ownership:** locale namespaces and shared accessibility primitives have sole writers.
- **Handoff:** report locales/states tested, files/evidence, automated results and manual-review gaps.
