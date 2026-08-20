# Component → Package Mapping

## Contents

- Package Tiers
- Controls
- Display
- Feedback
- Layout
- Navigation
- B2B-Specific
- Icons & Logos
- File Upload
- Meta-Packages

---

## Package Tiers

Packages are organized in four tiers. Tier shows in the prefix.

| Tier | Prefix | Purpose | Allowed deps |
|---|---|---|---|
| foundation | `@xsolla/xui-core`, `@xsolla/xui-icons-*`, `@xsolla/xui-logos-*`, `@xsolla/xui-primitives-*` | Tokens, hooks, primitives, icons, logos | foundation |
| base | `@xsolla/xui-<name>` | Cross-context components (web + native) | foundation + base |
| b2b | `@xsolla/xui-b2b-<name>` | B2B-only surfaces (web-focused) | foundation + base + b2b |
| b2c | `@xsolla/xui-b2c-<name>` | Reserved. No packages yet — never invent one | foundation + base + b2c |

Rule of thumb: prefer `@xsolla/xui-<name>` unless a `b2b-` variant exists for the specific surface.

---

## Controls

| Component | Package | Notes |
|---|---|---|
| Button | `@xsolla/xui-button` | `onPress`, `variant`, `tone`, `fullWidth`, `loading` |
| IconButton | `@xsolla/xui-button` | `onPress`, `tone`, `size`, `icon` |
| Checkbox | `@xsolla/xui-checkbox` | `onChange`, children for label |
| Radio | `@xsolla/xui-radio` | |
| RadioGroup | `@xsolla/xui-radio-group` | |
| Switch | `@xsolla/xui-switch` | `onValueChange`, `label`, `state` |
| Input | `@xsolla/xui-input` | `onChangeText`, `iconLeft`, `iconRight` |
| InputCopy | `@xsolla/xui-input-copy` | Copy-to-clipboard trailing button |
| InputPassword | `@xsolla/xui-input-password` | Visibility toggle |
| InputPayment | `@xsolla/xui-input-payment` | Card / payment fields |
| InputPhone | `@xsolla/xui-input-phone` | Phone with country selector |
| InputPin | `@xsolla/xui-input-pin` | OTP / verification |
| InputTime | `@xsolla/xui-input-time` | HH/MM/SS + optional AM/PM |
| TextArea | `@xsolla/xui-textarea` | |
| Select | `@xsolla/xui-select` | `onChange` |
| MultiSelect | `@xsolla/xui-multi-select` | |
| Autocomplete | `@xsolla/xui-autocomplete` | |
| Dropdown | `@xsolla/xui-dropdown` | |
| Slider | `@xsolla/xui-slider` | Range input |
| ColorPicker | `@xsolla/xui-color-picker` | |
| DatePicker | `@xsolla/xui-date-picker` | Combined Calendar + InputDate |
| Calendar | `@xsolla/xui-calendar` | Standalone calendar grid |
| Segmented | `@xsolla/xui-segmented` | |
| CheckboxTagGroup | `@xsolla/xui-checkbox-tag-group` | |
| ToggleButtonGroup | `@xsolla/xui-toggle-button-group` | |

## Display

| Component | Package | Notes |
|---|---|---|
| Typography | `@xsolla/xui-typography` | Variants: `h1`–`h5`, `display`, `body{Lg,Md,Sm,Xs,Xxs}` + `*Accent`, `*Paragraph` |
| Avatar | `@xsolla/xui-avatar` | |
| Badge | `@xsolla/xui-badge` | |
| Tag | `@xsolla/xui-tag` | |
| TagLabel | `@xsolla/xui-tag-label` | |
| Status | `@xsolla/xui-status` | Colored dot indicator |
| Image | `@xsolla/xui-image` | |
| ImageThumbnail | `@xsolla/xui-image-thumbnail` | |
| Divider | `@xsolla/xui-divider` | |
| Markdown | `@xsolla/xui-markdown` | |
| RichIcon | `@xsolla/xui-rich-icon` | |
| IconWrapper | `@xsolla/xui-icon-wrapper` | |
| SvgThemed | `@xsolla/xui-svg-themed` | |
| GameCard | `@xsolla/xui-game-card` | |
| QuestCard | `@xsolla/xui-quest-card` | |

## Feedback

| Component | Package | Notes |
|---|---|---|
| Notification | `@xsolla/xui-notification` | `tone`, `type: "toast" \| "inline"` |
| NotificationPanel | `@xsolla/xui-notification-panel` | |
| Toast | `@xsolla/xui-toast` | Requires `ToastProvider`; `useToast()` |
| Spinner | `@xsolla/xui-spinner` | |
| Tooltip | `@xsolla/xui-tooltip` | |
| Toggletip | `@xsolla/xui-toggletip` | |
| ProgressBar | `@xsolla/xui-progress-bar` | |
| ProgressLine | `@xsolla/xui-progress-line` | |
| Stepper | `@xsolla/xui-stepper` | B2B surfaces prefer `@xsolla/xui-b2b-stepper` |
| SupportingText | `@xsolla/xui-supporting-text` | |

## Layout

| Component | Package | Notes |
|---|---|---|
| Modal | `@xsolla/xui-modal` | Requires `ModalProvider`; `useModal()`; `type: "popup" \| "bottom-sheet" \| "full-screen"` |
| Bounding | `@xsolla/xui-bounding` | Responsive width constraint |
| Cell | `@xsolla/xui-cell` | |
| List | `@xsolla/xui-list` | |
| FieldGroup | `@xsolla/xui-field-group` | |
| ContextMenu | `@xsolla/xui-context-menu` | Sizes: sm/md/lg/xl; presets: list/phone/checkbox/status/brandLogo/radio/avatar |
| StatusDropdown | `@xsolla/xui-status-dropdown` | Status-selector wrapper around ContextMenu |

## Navigation

| Component | Package | Notes |
|---|---|---|
| Tabs | `@xsolla/xui-tabs` | `variant="segmented"` covers RadioGroup use cases |
| NavBar | `@xsolla/xui-nav-bar` | |
| TabBar | `@xsolla/xui-tab-bar` | |
| Breadcrumbs | `@xsolla/xui-breadcrumbs` | |
| Link | `@xsolla/xui-link` | |
| Pagination | `@xsolla/xui-pagination` | |

## B2B-Specific

Use these on B2B surfaces. No Switch equivalent.

| Component | Package |
|---|---|
| Drawer | `@xsolla/xui-b2b-drawer` |
| Sidebar | `@xsolla/xui-b2b-sidebar` |
| Stepper (B2B) | `@xsolla/xui-b2b-stepper` |
| NotificationPanel (B2B) | `@xsolla/xui-b2b-notification-panel` |
| Accordion | `@xsolla/xui-b2b-accordion` |
| Collapsible | `@xsolla/xui-b2b-collapsible` |
| GroupSelect | `@xsolla/xui-b2b-group-select` |
| Toast (B2B) | `@xsolla/xui-b2b-toast` |

## Icons & Logos

| Package | Content |
|---|---|
| `@xsolla/xui-icons-base` | UI icons (smaller bundle, recommended) |
| `@xsolla/xui-icons` | All icons (barrel export) |
| `@xsolla/xui-icons-brand` | Third-party brand icons |
| `@xsolla/xui-icons-currency` | Currency symbols |
| `@xsolla/xui-icons-flag` | Country flags |
| `@xsolla/xui-icons-payment` | Payment methods |
| `@xsolla/xui-icons-product` | Xsolla products |
| `@xsolla/xui-logos-brand` | Third-party brand logos |
| `@xsolla/xui-logos-xsolla` | Xsolla logos |
| `@xsolla/xui-store-badge` | App Store / Play Store badges |

## File Upload

| Component | Package |
|---|---|
| Uploader | `@xsolla/xui-uploader` |
| ImageUploader | `@xsolla/xui-image-uploader` |

## Meta-Packages

Prefer individual packages for tree-shaking. Meta-packages re-export sets.

| Package | Contains |
|---|---|
| `@xsolla/xui-controls` | All controls |
| `@xsolla/xui-display` | All display |
| `@xsolla/xui-feedback` | All feedback |
| `@xsolla/xui-navigation` | All navigation |
| `@xsolla/xui-layout` | All layout |
