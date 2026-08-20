# Migration: Switch → XUI Toolkit

## Contents

- Package Transforms
- Prop Transforms
- Icon Transforms
- Validation Checklist
- Example Transform
- Dependencies to Remove

---

## Package Transforms

```
@xsolla/design-system-core       → @xsolla/xui-core
@xsolla/design-system-themes     → @xsolla/xui-core
@xsolla/design-system-icons      → @xsolla/xui-icons-base
@xsolla/design-system-graphics   → @xsolla/xui-logos-brand, @xsolla/xui-logos-xsolla
@xsolla/design-system-controls   → individual packages (see component-library-reference.md)
@xsolla/design-system-display    → individual packages
@xsolla/design-system-navigation → individual packages
@xsolla/design-system-feedback   → individual packages
```

---

## Prop Transforms

### Sizes (unchanged)

```
"xs" | "sm" | "md" | "lg" | "xl"
```

### Button

```
variant="primary"   → variant="primary"   tone="brand"
variant="secondary" → variant="secondary" tone="brand"
variant="danger"    → variant="primary"   tone="alert"
stretched           → fullWidth
fetching            → loading
onClick             → onPress
<Button><Icon/></Button> → <Button iconLeft={<Icon/>} /> or iconRight
```

### Switch

```
children      → label="…"
errorMessage  → errorLabel="…"
error         → state="error"
disabled      → disabled (or state="disable")
onChange(e)   → onValueChange(boolean)
```

### Checkbox

```
label="…"     → <Checkbox>…</Checkbox>   // label via children
onChange      → onChange (unchanged)
disabled      → disabled (or state="disable")
```

### Select

```
onSelect      → onChange
options       → options (unchanged shape)
```

### Input

```
icon + iconPosition="left"  → iconLeft={<Icon/>}
icon + iconPosition="right" → iconRight={<Icon/>}
onChange(e)                 → onChangeText(string)
```

### RadioGroup

```
RadioGroup          → RadioGroup (@xsolla/xui-radio-group)  OR  Tabs variant="segmented"
options[].value     → <Radio value="…" />
options[].label     → <Radio label="…" />
```

### Theme hook

```
useDesignSystem()                    → useDesignSystem()        // global reads / mode switching
                                     → useResolvedTheme({…})    // per-component overrides
```

---

## Icon Transforms

Drop `Icon` prefix. Import from `@xsolla/xui-icons-base`.

```
IconSearch        → Search
IconChevronRight  → ChevronRight
IconUser          → User
IconCheckCr       → CheckCircle
IconRemoveCr      → XCircle
```

---

## Validation Checklist

Critical Rules table in SKILL.md is the source of truth — this list only flags migration-specific items beyond that.

1. All imports rewritten to `@xsolla/xui-*` (no leftover `@xsolla/design-system-*`).
2. All Critical Rules from SKILL.md satisfied (event names, sizes, tone vs variant, fullWidth, etc.).
3. Typography wrapped with explicit `style={{ color: theme.colors.content.* }}` — never inherits.
4. `useResolvedTheme({ themeMode, themeProductContext })` used in custom components needing override support; `useDesignSystem()` only for global reads / mode toggles.
5. Layout migrated to XUI primitives (Modal, Cell, List, FieldGroup, Bounding) — no leftover legacy layout components.
6. Removed deps purged from `package.json` (see Dependencies to Remove).

---

## Example Transform

```tsx
// Before
<Button variant="primary" size="md" stretched fetching={loading} onClick={fn}>
  Continue <IconChevronRight />
</Button>

// After
import { Button } from "@xsolla/xui-button";
import { ChevronRight } from "@xsolla/xui-icons-base";

<Button
  variant="primary"
  tone="brand"
  size="md"
  fullWidth
  loading={loading}
  onPress={fn}
  iconRight={<ChevronRight />}
>
  Continue
</Button>
```

---

## Dependencies to Remove

```bash
npm uninstall react-use downshift react-datepicker react-dropzone react-imask react-text-mask
```

XUI ships these capabilities in dedicated packages (`@xsolla/xui-date-picker`, `@xsolla/xui-uploader`, etc.).
