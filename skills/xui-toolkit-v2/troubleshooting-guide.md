# Troubleshooting

## Contents

- Installation
- Theme Issues
- Build Issues
- Runtime Issues
- Cross-Platform Issues
- Quick Fixes
- Config Snippets

---

## Installation

| Issue | Fix |
|---|---|
| TypeScript can't resolve imports | Set `moduleResolution: "bundler"` in `tsconfig.json` |
| Peer dependency warnings (web) | `yarn add styled-components@^4.4.1` |
| Peer dependency warnings (native) | `yarn add react-native-svg@^13.0.0` |
| Yarn lockfile drift on workspace dep | Run `yarn install` locally, commit updated `yarn.lock` |

---

## Theme Issues

| Issue | Fix |
|---|---|
| Typography text invisible / black on dark bg | Typography does not auto-inherit theme color. Pass `style={{ color: theme.colors.content.primary }}` explicitly. |
| Button text low contrast | Verify `variant` + `tone`. Brand buttons handle contrast automatically. |
| Components unstyled | `XUIProvider` missing or nested too deep. Mount at app root. |
| Colors don't change on mode switch | Read via `useResolvedTheme` / `useDesignSystem`, never hex literals. |
| Inputs washed out | Use `initialMode="light"` for light backgrounds. |
| styled-components can't access XUI theme | Read tokens via `useDesignSystem()`; pass values as props. |
| Per-component override not applying in custom component | Replace `useDesignSystem()` with `useResolvedTheme({ themeMode, themeProductContext })`. |

---

## Build Issues

| Issue | Fix |
|---|---|
| Bundle too large | Import from individual packages, not `@xsolla/xui-controls` / `xui-display` / etc. |
| `Cannot find module styled-components` | `yarn add styled-components@^4.4.1` |
| Metro can't resolve packages | `yarn start --reset-cache` |
| Vite "Unexpected token" | Add XUI packages to `optimizeDeps.exclude` |
| Webpack 5: `Can't resolve 'react/jsx-runtime'` from `.mjs` | Add rule: `{ test: /\.mjs$/, include: /node_modules/, resolve: { fullySpecified: false } }` |

---

## Runtime Issues

| Issue | Fix |
|---|---|
| `onClick` doesn't fire on Button | Use `onPress` |
| `onChange` doesn't fire on Input | Use `onChangeText` (text-value handler) |
| `onChange` doesn't fire on Switch | Use `onValueChange` (Checkbox keeps `onChange`) |
| Icons render blank | Web: verify SVG bundler config. Native: `yarn add react-native-svg`. |
| "Invalid hook call" | Multiple React copies. Use `resolutions` in `package.json`. |
| Modal does not open | `ModalProvider` not mounted, or `useModal` called outside its tree. |
| Toast does not appear | `ToastProvider` missing; or `useToast()` called outside provider. |
| ContextMenu offset wrong | Default trigger spacing is 4 px; override via `panelWidth` / placement props. |

---

## Cross-Platform Issues

| Issue | Fix |
|---|---|
| Different rendering web vs native | Stick to XUI components + theme tokens; platform differences handled internally. |
| CSS grid does not work on native | Use Flexbox only. |
| `window` / `document` undefined on native | Guard with `Platform.OS === "web"` or use platform-agnostic APIs. |
| `boxShadow` invisible on native | Use `elevation` + `shadowColor` / `shadowOffset` / `shadowOpacity` / `shadowRadius`. |

---

## Quick Fixes

```bash
# Clear caches
rm -rf node_modules/.vite       # Vite
yarn start --reset-cache        # Metro

# Reinstall
rm -rf node_modules && yarn install

# Inspect versions
yarn list @xsolla/xui-core
yarn why react
```

---

## Config Snippets

### `tsconfig.json`

```json
{
  "compilerOptions": {
    "moduleResolution": "bundler"
  }
}
```

### Webpack 5 (`.mjs` ESM resolution)

```js
module.exports = {
  module: {
    rules: [
      {
        test: /\.mjs$/,
        include: /node_modules/,
        resolve: { fullySpecified: false },
      },
    ],
  },
};
```

### `package.json` (React duplicate fix)

Pin to the React version the consuming project already uses (most Xsolla teams are on React 16, so `^16.14.0` below — swap as needed):

```json
{
  "resolutions": {
    "react": "^16.14.0",
    "react-dom": "^16.14.0"
  }
}
```
