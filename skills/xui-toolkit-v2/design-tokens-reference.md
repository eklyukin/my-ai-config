# Design Tokens Reference

Access via `const { theme } = useResolvedTheme({});` from `@xsolla/xui-core` (or `useDesignSystem()` for global reads).

## Contents

- Common Patterns
- Colors
- Spacing
- Radius
- Shadow
- Fonts
- Sizing Functions

---

## Common Patterns

Copy these before inventing new paths. Most custom components only need a handful of tokens.

```tsx
const { theme } = useResolvedTheme({});

// App background + body text
backgroundColor: theme.colors.background.primary,
color: theme.colors.content.primary,

// Card / panel
backgroundColor: theme.colors.background.secondary,
borderRadius: theme.radius.card,
boxShadow: theme.shadow.surface,
padding: theme.spacing.m,

// Muted helper text
color: theme.colors.content.secondary,

// Alert / error region
backgroundColor: theme.colors.background.alert.secondary,
color: theme.colors.content.alert.primary,
borderColor: theme.colors.border.alert,

// Brand accent button surface
backgroundColor: theme.colors.control.brand.primary.bg,
color: theme.colors.control.brand.primary.text.primary,

// Input field
backgroundColor: theme.colors.control.input.bg,
borderColor: theme.colors.control.input.border,
color: theme.colors.control.input.text,

// Modal scrim / focus ring
backgroundColor: theme.colors.layer.scrim,
boxShadow: `0 0 0 2px ${theme.colors.control.focus.bg}`,
```

---

## Colors

Theme-aware (dark / light / ltg-dark). Use paths, never hex.

```
theme.colors.background.{primary, secondary, inverse}
theme.colors.background.{brand, brandExtra, success, warning, alert, neutral}.{primary, secondary}

theme.colors.content.{primary, secondary, tertiary, inverse}
theme.colors.content.{brand, brandExtra, success, warning, alert, neutral}.{primary, secondary}
theme.colors.content.on.{brand, brandExtra, success, warning, alert, neutral}   // text on colored bg
theme.colors.content.static.{light, dark}                                       // ignores theme mode

theme.colors.border.{primary, secondary, inverse}
theme.colors.border.{brand, brandExtra, success, warning, alert, neutral}

theme.colors.overlay.{mono, brand, brandExtra, success, warning, alert, neutral}

theme.colors.layer.{scrim, float}

theme.colors.control.{brand, brandExtra, alert, mono}.{primary, secondary, tertiary}
  .{bg, bgHover, bgPress, bgDisable, border, borderHover, borderPress, borderDisable}
  .text.{primary, secondary, disable}

theme.colors.control.input.{bg, bgHover, bgDisable, border, borderHover, borderDisable, text, textDisable, placeholder}
theme.colors.control.focus.bg
theme.colors.control.check.{bg, bgHover, bgDisable}
theme.colors.control.faint.{bg, bgHover, border, borderHover}
theme.colors.control.switch.{bg, bgHover}
theme.colors.control.segmented.{bg, bgHover, bgActive, textActive}
theme.colors.control.text.{primary, secondary, faint, disable}
theme.colors.control.link.{primary, primaryHover, secondary, secondaryHover}
```

---

## Spacing

```
theme.spacing.xs = 4    theme.spacing.s = 8    theme.spacing.m = 16
theme.spacing.l = 24    theme.spacing.xl = 32
```

---

## Radius

```
theme.radius.button = 4         theme.radius.card = 12
theme.radius.input = 4          theme.radius.avatarCircle = 999
theme.radius.tagSmall = 4       theme.radius.tagMedium = 6       theme.radius.tagLarge = 8
theme.radius.avatarSmall = 4    theme.radius.avatarLarge = 8
```

---

## Shadow

```
theme.shadow.{active, surface, surfaceHover, popover, modal}
```

---

## Fonts

```
theme.fonts.heading   // display family (Pilat / Pilat Wide depending on context)
theme.fonts.body      // body family (Aktiv Grotesk)
theme.fonts.text      // paragraph family (same as body)
theme.fonts.primary   // deprecated alias for body
```

Responsive typography on web: CSS variables auto-injected by `XUIProvider`.
- Font sizes: `--xui-font-size-{75 | 100 | 125 | 150 | 175 | 200 | 250 | 300 | 350 | 450 | 550 | 650 | 750}`
- Line heights: `--xui-lh-{display | compact | text}-{step}`
- Breakpoint: 768 px

---

## Sizing Functions

`theme.sizing.<fn>(size)` returns per-size metrics. Use for custom component styling.

| Function | Sizes | Returns |
|---|---|---|
| `button(size)` | xs sm md lg xl | height, padding, fontSize, sublabelFontSize, spinnerSize, iconSize, iconContainerSize, iconPadding, loadingPadding, borderRadius, labelIconSize, labelIconGap |
| `flexButton(size)` | xs sm md lg xl | height, padding, fontSize, spinnerSize, iconSize, borderRadius |
| `input(size)` | xs sm md lg xl | height, paddingVertical, paddingHorizontal, fontSize, iconSize, radius, borderWidth, fieldGap, lineHeight |
| `inputPin(size)` | xs sm md lg xl | size, gap, fontSize, radius, borderWidth |
| `textarea(size)` | xs sm md lg xl | height, padding, fontSize, iconSize |
| `imageUploader(size)` | xs sm md lg xl | dimensions per size |
| `checkbox(size)` | sm md lg xl | size, fontSize, descriptionFontSize, labelGap, textGap, borderRadius |
| `radio(size)` | sm md lg xl | size, fontSize, lineHeight, descriptionFontSize, descriptionLineHeight, labelGap, textGap, borderWidth |
| `switch(size)` | sm md lg xl | width, height, knobSize, fontSize, lineHeight, descriptionFontSize, descriptionLineHeight, labelGap, textGap, frameBorderRadius, knobBorderRadius |
| `avatar(size)` | xs sm md lg xl | size, fontSize, iconSize, badgeSize, badgeOffsetCircle, badgeOffsetSquare, borderRadiusSquare, borderRadiusCircle |
| `tag(size)` | xs sm md lg xl | height, padding, fontSize, gap, iconSize, radius |
| `badge(size)` | xs sm md lg xl | size, fontSize, lineHeight, iconSize, padding |
| `spinner(size)` | xs sm md lg xl | size, strokeWidth |
| `divider(size)` | sm md lg | height, fontSize, lineWeight |
| `tabs(size)` | sm md lg xl | height, fontSize, iconSize, gap, paddingHorizontal |
| `segmented(size)` | sm md lg xl | height, fontSize, iconSize, gap, padding |
| `tabsSegmented(size)` | sm md lg xl | height, containerPadding, containerRadius, itemPaddingHorizontal, itemPaddingVertical, itemRadius, fontSize, lineHeight, iconSize, gap |
| `checkboxTagGroup(size)` | sm md lg xl | height, paddingHorizontal, paddingVertical, fontSize, lineHeight, gap, borderRadius |
| `notification(type)` | "toast" \| "inline" | width, paddingHorizontal, paddingVertical, gap, titleSize, messageSize, iconSize, iconWrapperSize, radius |
| `progress(size)` | xxs xs sm md lg xl | height, labelSize, helperSize, gap |
| `supportingText(size)` | xs sm md lg xl | fontSize, lineHeight, gap, iconSize |
| `iconWrapper(size)` | xxs xs sm md lg xl | size, iconSize, fontSize |
| `stepper(size)` | sm md | iconSize, titleSize, descSize, gap, currentTitleSize, currentDescSize, currentPadding, tailSize |
| `contextMenu(size)` | sm md lg xl | paddingVertical, itemPaddingHorizontal, itemPaddingVertical, fontSize, lineHeight, descriptionFontSize, iconSize, gap, minWidth, panelWidth, statusDotSize, iconWrapperSize, triggerOffset, borderRadius, search* |
| `toggleButtonGroup(size)` | sm md lg xl | per-button metrics |
| `modal()` | (none) | borderRadius, headerPadding, contentPadding, headerButtonSize, headerGap, shadow |
| `drawer()` | (none) | width, padding, shadow |
| `toast()` | (none) | minHeight, paddingHorizontal, paddingVertical, borderRadius, gap, iconSize, closeButtonSize, closeIconSize, fontSize, lineHeight, maxWidth, containerPadding, groupGap |
