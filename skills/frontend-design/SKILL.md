---
name: frontend-design
description: Create distinctive, production-grade frontend interfaces with high design quality. Use this skill when the user asks to build web components, pages, artifacts, posters, or applications (examples include websites, landing pages, dashboards, React components, HTML/CSS layouts, or when styling/beautifying any web UI). Generates creative, polished code and UI design that avoids generic AI aesthetics.
license: Complete terms in LICENSE.txt
---

This skill guides creation of distinctive, production-grade frontend interfaces that avoid generic "AI slop" aesthetics. Implement real working code with exceptional attention to aesthetic details and creative choices.

The user provides frontend requirements: a component, page, application, or interface to build. They may include context about the purpose, audience, or technical constraints.

## Design Thinking

Before coding, understand the context and commit to a BOLD aesthetic direction:
- **Purpose**: What problem does this interface solve? Who uses it?
- **Tone**: Pick an extreme: brutally minimal, maximalist chaos, retro-futuristic, organic/natural, luxury/refined, playful/toy-like, editorial/magazine, brutalist/raw, art deco/geometric, soft/pastel, industrial/utilitarian, etc. There are so many flavors to choose from. Use these for inspiration but design one that is true to the aesthetic direction.
- **Constraints**: Technical requirements (framework, performance, accessibility).
- **Differentiation**: What makes this UNFORGETTABLE? What's the one thing someone will remember?

**CRITICAL**: Choose a clear conceptual direction and execute it with precision. Bold maximalism and refined minimalism both work - the key is intentionality, not intensity.

Then implement working code (HTML/CSS/JS, React, Vue, etc.) that is:
- Production-grade and functional
- Visually striking and memorable
- Cohesive with a clear aesthetic point-of-view
- Meticulously refined in every detail

## Frontend Aesthetics Guidelines

Focus on:
- **Typography**: Choose fonts that are beautiful, unique, and interesting. Avoid generic fonts like Arial and Inter; opt instead for distinctive choices that elevate the frontend's aesthetics; unexpected, characterful font choices. Pair a distinctive display font with a refined body font.
- **Color & Theme**: Commit to a cohesive aesthetic. Use CSS variables for consistency. Dominant colors with sharp accents outperform timid, evenly-distributed palettes.
- **Motion**: Use animations for effects and micro-interactions. Prioritize CSS-only solutions for HTML. Use Motion library for React when available. Focus on high-impact moments: one well-orchestrated page load with staggered reveals (animation-delay) creates more delight than scattered micro-interactions. Use scroll-triggering and hover states that surprise.
- **Spatial Composition**: Unexpected layouts. Asymmetry. Overlap. Diagonal flow. Grid-breaking elements. Generous negative space OR controlled density.
- **Backgrounds & Visual Details**: Create atmosphere and depth rather than defaulting to solid colors. Add contextual effects and textures that match the overall aesthetic. Apply creative forms like gradient meshes, noise textures, geometric patterns, layered transparencies, dramatic shadows, decorative borders, custom cursors, and grain overlays.

NEVER use generic AI-generated aesthetics like overused font families (Inter, Roboto, Arial, system fonts), cliched color schemes (particularly purple gradients on white backgrounds), predictable layouts and component patterns, and cookie-cutter design that lacks context-specific character.

Interpret creatively and make unexpected choices that feel genuinely designed for the context. No design should be the same. Vary between light and dark themes, different fonts, different aesthetics. NEVER converge on common choices (Space Grotesk, for example) across generations.

**IMPORTANT**: Match implementation complexity to the aesthetic vision. Maximalist designs need elaborate code with extensive animations and effects. Minimalist or refined designs need restraint, precision, and careful attention to spacing, typography, and subtle details. Elegance comes from executing the vision well.

## Redesigning Existing Applications

When the user asks to redesign (not build from scratch), adapt the workflow:

1. **Read before restyling**: Understand the existing component architecture, state management, and data flow. Don't refactor structure — restyle in place.
2. **Identify the token layer**: Find where colors, fonts, and spacing are defined (CSS variables, Tailwind `@theme`, styled-components theme, etc.). Change tokens first — they cascade everywhere.
3. **Migration strategy**: Use `replace_all` for hardcoded color values across all files. This is faster and safer than hunting individual occurrences.
4. **Don't break functionality**: After visual changes, run `tsc --noEmit` and the build tool (Vite, Webpack, etc.) to catch regressions. Visual-only changes should never break types or builds.
5. **Inline styles vs utility classes**: Never use Tailwind-only utilities (like `ring-*`, `divide-*`) as CSS properties in inline `style={{}}` objects — they don't exist in CSS. Use `boxShadow` or `border` equivalents instead.

## Browser and Design Verification

When implementing or changing a user interface:

1. Use Playwright MCP and Chrome DevTools MCP when they are connected and available.
2. You MUST inspect and reuse the user's already-open Google Chrome session before opening another browser. Use the obvious matching tab; ask which existing tab to use when multiple tabs are plausible or acting could change user state.
3. Open new URLs in a new tab in the existing Chrome window and profile. Never silently launch a separate isolated browser; report the limitation first if the existing session cannot support the operation.
4. After making UI changes, open the affected screen and inspect its rendered state. Use screenshots and browser diagnostics to check layout, overflow, spacing, responsive behavior, console errors, and failed network requests.
5. When a Figma design exists and Figma MCP is connected, inspect the relevant design through Figma MCP and compare the implementation against it, including all supplied breakpoints and states.
6. Do not consider visual verification complete based only on a successful build, test run, or opened URL. Visually inspect the rendered result.
7. If a required MCP server is unavailable, report the limitation and use the closest available verification method.

### Tool Priority

- Use Chrome DevTools MCP for the user's already-open Chrome session and authenticated pages.
- Use Playwright MCP for repeatable scenarios, responsive viewport checks, and automated UI verification while reusing the existing Chrome session whenever supported.
- Use Figma MCP to inspect and compare against the source design when a Figma layout exists and the server is connected.

## Brand Alignment

When an app has an existing design system or brand guidelines (e.g., DESIGN.md, style guide):
- **External-facing apps**: Follow brand colors and typography strictly. Creative expression happens through layout, motion, and spatial composition.
- **Internal tools and dashboards**: May deviate from brand colors to optimize for readability and data density (e.g., warmer cyan for better contrast on deep blacks, muted accents to reduce eye strain). Document deviations in the CSS as comments.

Remember: Claude is capable of extraordinary creative work. Don't hold back, show what can truly be created when thinking outside the box and committing fully to a distinctive vision.
