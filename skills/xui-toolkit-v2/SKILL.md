---
name: xui-toolkit-v2
description: "Generates React and React Native UI code using Xsolla's XUI Toolkit V2, including XUI, @xsolla/xui-* packages, the Xsolla design system, design tokens, theming, theme overrides, Storybook references at xsolla-ui-toolkit-v2.web.app, migrations from @xsolla/design-system-*, and React or React Native component work in Xsolla repositories. Do not use for backend APIs, business logic, or data fetching."
---

# XUI Toolkit V2

## Contents

- Loading Reference Files
- Core Philosophy
- Version Check Protocol
- Quick Setup
- Theme Modes & Product Contexts
- Package Tiers
- Critical Rules
- Component Examples
- Per-Component Theme Overrides
- React Native Notes
- Before / After Migration
- Honesty Protocol
- References

---

## Loading Reference Files

This SKILL.md covers the common cases. Load a reference file **only when the task matches** — reading all four wastes tokens on every invocation.

| Task signal | Load |
|---|---|
| Migrating off `@xsolla/design-system-*` or rewriting legacy code | `migration-guide.md` |
| User asks about a component / prop / package you don't see covered here, OR you'd otherwise guess at a package name | `component-library-reference.md` |
| Token lookup: specific color role, spacing scale, radius, content/background variant | `design-tokens-reference.md` |
| Webpack/Vite/Metro build error, Server Component runtime error, hydration mismatch, font/font-face issue | `troubleshooting-guide.md` |

If the task is purely a code example using one of the components shown below (Button, Typography, Input, Switch, Checkbox, Select, Modal, Toast, Icons), do not load any reference file — the inline examples are complete.

---

## Core Philosophy

Cross-platform React / React-Native design system. One component package (`@xsolla/xui-<name>`) per UI element. Bundler resolves the platform-specific implementation via conditional exports. Consumers write code once and ship to both web and native.

---

## Version Check Protocol

Only check npm when (a) user runs an install command, (b) user asks "what version", or (c) user reports a version-specific bug. Skip for normal code generation — adding noise on every example wastes turns.

When triggered:
1. Fetch `@xsolla/xui-core` from https://www.npmjs.com/package/@xsolla/xui-core.
2. Use that version in the install command. Pin only if user asks.
3. Report version to user once per session.

---

## Quick Setup

### Install

Use the project's existing package manager (check for `yarn.lock` / `package-lock.json` / `pnpm-lock.yaml`). Examples use `npm`; swap `npm install` → `yarn add` / `pnpm add` as needed.

```bash
# Web
npm install @xsolla/xui-core @xsolla/xui-button @xsolla/xui-typography styled-components@^4.4.1

# Native
npm install @xsolla/xui-core @xsolla/xui-button @xsolla/xui-typography react-native-svg
```

### Wrap app

```tsx
import { XUIProvider } from "@xsolla/xui-core";
import { ModalProvider } from "@xsolla/xui-modal";

<XUIProvider initialMode="dark">
  <ModalProvider>
    <App />
  </ModalProvider>
</XUIProvider>
```

Pass `loadFonts={false}` to `XUIProvider` on React Native.

Webpack 5 users: if you get `Can't resolve 'react/jsx-runtime'`, see [troubleshooting-guide.md](./troubleshooting-guide.md).

---

## Theme Modes & Product Contexts

### Modes (`initialMode`)

| Mode | Notes |
|---|---|
| `"dark"` | Default |
| `"light"` | |
| `"ltg-dark"` | LTG brand dark |
| `"pentagram-dark"` | Deprecated alias for `"dark"` |
| `"pentagram-light"` | Deprecated alias for `"light"` |

### Product contexts (`initialProductContext`)

| Context | Notes |
|---|---|
| `"b2b"` | Default. Larger sizes, lighter heading weights |
| `"b2c"` | Consumer-facing, bold headings |
| `"paystation"` | Compact typography |
| `"presentation"` | Large displays |

---

## Package Tiers

| Tier | Prefix | Purpose |
|---|---|---|
| foundation | `@xsolla/xui-core`, `@xsolla/xui-icons-*`, `@xsolla/xui-logos-*`, `@xsolla/xui-primitives-*` | Tokens, hooks, primitives, icons, logos |
| base | `@xsolla/xui-<name>` | Cross-context components (web + native) |
| b2b | `@xsolla/xui-b2b-<name>` | B2B-only surfaces (web-focused) |
| b2c | `@xsolla/xui-b2c-<name>` | Reserved. No packages yet — never invent one |

Prefer `@xsolla/xui-<name>` unless a `b2b-` variant exists for the specific surface.

---

## Critical Rules

| Concern | Correct | Wrong |
|---|---|---|
| Button events | `onPress` | `onClick` |
| Switch events | `onValueChange` | `onChange` |
| Checkbox events | `onChange` | `onValueChange` |
| Select events | `onChange` | `onSelect` |
| Input events | `onChangeText(value: string)` — cross-platform, no event object | `onChange(e)` |
| Sizes | `"xs" \| "sm" \| "md" \| "lg" \| "xl"` (subset per component) | `"s" \| "m" \| "l"` |
| Destructive button | `tone="alert"` | `variant="destructive"` |
| Full-width button | `fullWidth` | `stretched` |
| Loading button | `loading` | `fetching` |
| Switch label | `label="…"` | `<Switch>…</Switch>` |
| Checkbox label | `<Checkbox>…</Checkbox>` (children) | `label="…"` |
| Icon in button | `iconLeft={<ChevronRight />}` | `<Button><ChevronRight /></Button>` |
| Icon names | `import { Search } from "@xsolla/xui-icons-base"` | `IconSearch` prefix |
| Typography color | `style={{ color: theme.colors.content.primary }}` | omit color |
| Colors | `theme.colors.background.primary` | hex `"#202a2c"` |
| Spacing | `theme.spacing.m` | `"16px"` |
| Server Components | `XUIProvider` lives in a client component (`"use client"` at top) — typically `providers.tsx` mounted from root `layout.tsx`. All interactive XUI components inherit client boundary. | XUIProvider or `useResolvedTheme` in an RSC |
| Theme override | `<Button themeMode="light" />` on base/b2b components, OR `useResolvedTheme({ themeMode })` inside a custom wrapper | nested `<XUIProvider>`, fabricated wrappers like `<ThemeScope>` / `<ThemeProvider>` / `<ModeOverride>` |
| Toast (base) | `toast.success("Saved")` — string overload from `@xsolla/xui-toast` | object with `title`/`description` against the base package |
| Toast (b2b) | `toast.success({ title, description, action: { label, onPress } })` from `@xsolla/xui-b2b-toast` — `action.onPress`, not `action.onClick` | string overload, or `action: { label, onClick }` |
| Primitives | `Typography` / standard HTML / `View` | `Box`, `Text` (internal) |

### Avoid hardcoded values

```tsx
// Wrong
<div style={{ backgroundColor: "#FF0000", padding: "16px" }} />

// Correct
const { theme } = useResolvedTheme({});
<div style={{ backgroundColor: theme.colors.background.alert, padding: theme.spacing.m }} />
```

---

## Component Examples

### Button

```tsx
import { Button } from "@xsolla/xui-button";
import { ChevronRight } from "@xsolla/xui-icons-base";

<Button variant="primary" tone="brand" size="md" onPress={handleClick} iconRight={<ChevronRight />}>
  Continue
</Button>

<Button variant="primary" tone="alert" onPress={handleDelete}>Delete</Button>
```

Variants: `primary | secondary | tertiary | ghost`. Tones: `brand | brandExtra | alert | mono`.

### Typography

```tsx
import { Typography } from "@xsolla/xui-typography";
import { useResolvedTheme } from "@xsolla/xui-core";

const { theme } = useResolvedTheme({});

<Typography variant="h1" style={{ color: theme.colors.content.primary }}>
  Heading
</Typography>

<Typography variant="bodyMd" style={{ color: theme.colors.content.secondary }}>
  Paragraph
</Typography>
```

Variants: `h1`–`h5`, `display`, `bodyLg | bodyMd | bodySm | bodyXs | bodyXxs` plus `*Accent` (semibold) and `*Paragraph` (looser line-height) suffixes.

### Form Controls

```tsx
import { Input } from "@xsolla/xui-input";
import { Checkbox } from "@xsolla/xui-checkbox";
import { Switch } from "@xsolla/xui-switch";
import { Select } from "@xsolla/xui-select";
import { Mail } from "@xsolla/xui-icons-base";

<Input label="Email" value={email} onChangeText={setEmail} size="md" iconLeft={<Mail />} />
<Checkbox checked={agreed} onChange={(e) => setAgreed(e.target.checked)}>I agree</Checkbox>
<Switch checked={enabled} onValueChange={setEnabled} label="Notifications" />
<Select options={countryOptions} value={country} onChange={setCountry} label="Country" size="md" />
```

### Modal

```tsx
import { ModalProvider, useModal, Modal } from "@xsolla/xui-modal";

// 1. Provider at app root
<XUIProvider><ModalProvider><App /></ModalProvider></XUIProvider>

// 2. Hook in any descendant
const [open, close] = useModal(() => (
  <Modal onClose={close} title="Confirm">
    <Typography variant="bodyMd">Proceed?</Typography>
    <Button onPress={close}>OK</Button>
  </Modal>
));

<Button onPress={open}>Open</Button>
```

Modal `type`: `popup` (default, centered), `bottom-sheet`, `full-screen`.

### Toast

```tsx
import { ToastProvider, useToast } from "@xsolla/xui-toast";

// 1. Provider at app root
<XUIProvider><ToastProvider position="top" defaultDuration={5000}><App /></ToastProvider></XUIProvider>

// 2. Hook in any descendant
const toast = useToast();
toast.success("Saved");
toast.error("Network error");
const id = toast.info({ message: "Saving…", duration: 0 });  // sticky
toast.dismiss(id);
```

For B2B surfaces use `@xsolla/xui-b2b-toast` — option shape differs:

```tsx
import { useToast } from "@xsolla/xui-b2b-toast";

const toast = useToast();
toast.success({
  title: "Saved",
  description: "Settings updated.",
  action: { label: "Undo", onPress: handleUndo },
});
```

### Icons

```tsx
import { Search, ArrowRight } from "@xsolla/xui-icons-base";

<Button iconLeft={<Search />} iconRight={<ArrowRight />}>Search</Button>
```

`@xsolla/xui-icons-base` for UI icons. `@xsolla/xui-icons` for the full barrel. Category-specific packages: `xui-icons-brand`, `xui-icons-currency`, `xui-icons-flag`, `xui-icons-payment`, `xui-icons-product`.

---

## Per-Component Theme Overrides

Base + b2b components (`@xsolla/xui-<name>`, `@xsolla/xui-b2b-<name>`) accept `themeMode` and `themeProductContext` props. Foundation packages (icons, logos, primitives) do not. Mix themes in one tree without nested providers.

If unsure whether a specific component supports overrides, check its props in Storybook or pass via `useResolvedTheme` inside a wrapper instead.

```tsx
<XUIProvider initialMode="dark">
  <Button themeMode="light" tone="brand">Light Button</Button>
  <Typography themeProductContext="b2c" variant="h1">B2C heading</Typography>
</XUIProvider>
```

### Custom components

```tsx
import { useResolvedTheme } from "@xsolla/xui-core";
import type { ThemeOverrideProps } from "@xsolla/xui-core";

function Card({ themeMode, themeProductContext, children }: ThemeOverrideProps & { children: ReactNode }) {
  const { theme } = useResolvedTheme({ themeMode, themeProductContext });
  return <div style={{ background: theme.colors.background.primary, padding: theme.spacing.m }}>{children}</div>;
}
```

`useResolvedTheme` respects per-component overrides. Use `useDesignSystem` only when reading or switching the global mode/context (e.g., a theme toggle UI).

---

## React Native Notes

| Concern | Native pattern |
|---|---|
| Layout containers | `View`, `ScrollView` from `react-native` |
| Fonts | `<XUIProvider loadFonts={false}>` |
| Input change | `onChangeText={setValue}` |
| Web-only CSS to avoid | `cursor`, `boxShadow`, `display: grid` |
| Shadows | Use `elevation` + native shadow* props, not `boxShadow` |
| Icons | Same `@xsolla/xui-icons-base` package; install `react-native-svg` peer dep |

---

## Before Migration

1. Check latest versions (Version Check Protocol).
2. Check existing packages: `grep "@xsolla/xui-" package.json`.
3. Verify components at: https://xsolla-ui-toolkit-v2.web.app.
4. Confirm design approval for XUI on the project.
5. Pick theme mode (`"dark"` default, `"light"`, or `"ltg-dark"`) matching the design's background.

## After Migration

Ask user: "Test in dev server — is text visible and components interactive?"

Verify:
- All Typography components have explicit `color` in `style`.
- No black text on dark backgrounds (check headings).
- No white-on-white text in light mode.
- Button text contrast OK.
- Interactive states work (hover, focus, press).
- Theme mode matches background.

---

## Honesty Protocol

- Before claiming a component exists, grep [component-library-reference.md](./component-library-reference.md). If absent there, do not fabricate a package name.
- Before claiming a component does **not** exist, check the same file plus Storybook (https://xsolla-ui-toolkit-v2.web.app) if reachable. If still unclear, ask the user — don't guess.
- Surface uncertainty explicitly: "Not listed in component-library-reference — please confirm."

### Known-fake patterns (never write these)

| Pattern | Why fake |
|---|---|
| `@xsolla/xui-b2c-<anything>` (`xui-b2c-hero`, `xui-b2c-card`, `xui-b2c-banner`, …) | Whole tier reserved, no packages published |
| `@xsolla/xui-toolkit-v2`, `@xsolla/xui-toolkit-v2/<sub>`, `@xsolla/xui-toolkit/<sub>` | XUI is one-package-per-component; no umbrella package |
| `@xsolla/xui-icons-base/IconSearch` or any `Icon<Name>` import | Icons export bare names: `import { Search } from "@xsolla/xui-icons-base"` |
| `<ThemeScope>`, `<ThemeProvider>`, `<ModeOverride>` (or any custom theme-mode wrapper) | Use `themeMode` prop or `useResolvedTheme({ themeMode })` — no wrapper component exists |
| `useTheme()` / `useDesignSystem()` for reading resolved tokens in a component | Use `useResolvedTheme({})` — `useDesignSystem` is only for global mode/context toggles |

When asked to use one of these, refuse the import, name the reason, then offer a composition from real packages (e.g., for `xui-b2c-hero`: `Typography` + `Button` + `useResolvedTheme` inside `themeProductContext="b2c"`).

---

## References

- **Component packages:** [component-library-reference.md](./component-library-reference.md)
- **Design tokens:** [design-tokens-reference.md](./design-tokens-reference.md)
- **Migration transforms:** [migration-guide.md](./migration-guide.md)
- **Troubleshooting:** [troubleshooting-guide.md](./troubleshooting-guide.md)
- **Storybook:** https://xsolla-ui-toolkit-v2.web.app
