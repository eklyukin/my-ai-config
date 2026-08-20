# Existing Browser Policy

When browser access is relevant and Playwright MCP or Chrome DevTools MCP is
available, reuse the user's already-running Google Chrome session by default.

1. Inspect the open Chrome tabs before navigating or launching another browser.
2. If one open tab clearly matches the task, use it. If multiple tabs are
   plausible, or acting in a tab could change user state, ask which tab to use.
3. For a new URL, open a new tab in the existing Chrome window and profile so
   that authentication, cookies, extensions, and application state are retained.
4. Never silently launch a separate managed, temporary, or isolated browser
   profile. Use one only when the task explicitly requires a clean profile, the
   existing session cannot support the operation, or the user agrees.
5. Prefer Chrome DevTools MCP for existing tabs, authenticated pages, console
   and network inspection, and performance debugging.
6. Prefer Playwright MCP for repeatable flows, responsive checks, and automated
   UI verification, but attach to or reuse the existing Chrome session whenever
   the available integration supports it.
7. If Playwright cannot attach to the existing session, use Chrome DevTools MCP
   for existing or authenticated pages. Report the limitation before falling
   back to an isolated browser.
8. Do not close or repurpose user-owned tabs or windows. Close only tabs created
   by the agent when doing so is safe and useful.
9. When a Figma design exists and Figma MCP is connected, inspect the source
   design before implementation and compare the rendered result against it.

