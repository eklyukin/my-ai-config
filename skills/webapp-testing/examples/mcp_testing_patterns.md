# MCP Browser Testing Patterns

Real-world patterns for testing with Claude-in-Chrome and Playwright MCP tools.

## Pattern 1: Verify deployment with Claude-in-Chrome

```
# Step 1: See what's open
→ mcp__claude-in-chrome__tabs_context_mcp

# Step 2: Navigate to deployed app
→ mcp__claude-in-chrome__navigate
  url: "https://prototype.xsolla.dev/mini-app-bundles/myapp/index.html"

# Step 3: Check for errors
→ mcp__claude-in-chrome__read_console_messages
  pattern: "error|fail|404|500"

# Step 4: Verify content rendered
→ mcp__claude-in-chrome__javascript_tool
  javascript: "document.querySelectorAll('.content-card').length"

# Step 5: Visual check
→ mcp__claude-in-chrome__read_page
```

## Pattern 2: Test localhost with Playwright MCP

```
# Step 1: Navigate (launches browser automatically)
→ mcp__plugin_playwright_playwright__browser_navigate
  url: "http://localhost:5173"

# Step 2: Get accessibility tree (cheap, no vision)
→ mcp__plugin_playwright_playwright__browser_snapshot

# Step 3: Check console
→ mcp__plugin_playwright_playwright__browser_console_messages

# Step 4: Interact
→ mcp__plugin_playwright_playwright__browser_click
  element: "Submit button"
  ref: "s1e5"  # from snapshot

# Step 5: Verify result
→ mcp__plugin_playwright_playwright__browser_snapshot
```

## Pattern 3: Debug API failures

```
# Navigate to app
→ browser_navigate to URL

# Check network requests for failures
→ mcp__plugin_playwright_playwright__browser_network_requests

# Look for 401/403/500 responses
# If auth issues: switch to Claude-in-Chrome (has user session)
# If CORS: check browser console for CORS errors
```

## Pattern 4: Record multi-step flow (Claude-in-Chrome)

```
# Start recording
→ mcp__claude-in-chrome__gif_creator
  action: "start"
  filename: "onboarding_flow.gif"

# Capture frames before each action
→ mcp__claude-in-chrome__gif_creator action: "capture_frame"
→ mcp__claude-in-chrome__navigate url: "..."
→ mcp__claude-in-chrome__gif_creator action: "capture_frame"
→ mcp__claude-in-chrome__form_input ...
→ mcp__claude-in-chrome__gif_creator action: "capture_frame"

# Stop and save
→ mcp__claude-in-chrome__gif_creator action: "stop"
```

## Anti-patterns

### DON'T: Retry failing Chrome extension connections
```
# BAD — will loop forever
→ tabs_context_mcp  # error: not connected
→ tabs_context_mcp  # error: not connected
→ tabs_context_mcp  # error: not connected
```
**DO**: Fail fast, switch to Playwright MCP or ask user for screenshot.

### DON'T: Navigate without /index.html on GCS
```
# BAD — returns 404
→ navigate url: "https://prototype.xsolla.dev/mini-app-bundles/voice/"

# GOOD
→ navigate url: "https://prototype.xsolla.dev/mini-app-bundles/voice/index.html"
```

### DON'T: Use Playwright MCP for auth-protected pages
```
# BAD — redirects to Okta login
→ browser_navigate url: "https://internal.xsolla.com/dashboard"

# GOOD — use Claude-in-Chrome (has user's session)
→ mcp__claude-in-chrome__navigate url: "https://internal.xsolla.com/dashboard"
```
