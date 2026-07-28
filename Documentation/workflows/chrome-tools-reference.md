# Chrome MCP Tools Reference

Quick reference for browser automation tools available in Claude Code.

## Available Tools

### Navigation & Context

| Tool | Purpose |
|------|---------|
| `tabs_context_mcp` | Get/create browser tab context |
| `tabs_create_mcp` | Create new tab in MCP group |
| `navigate` | Go to URL or back/forward |

### Page Interaction

| Tool | Purpose |
|------|---------|
| `computer` | Mouse/keyboard actions, screenshots |
| `read_page` | Get accessibility tree of page |
| `find` | Find elements by natural language |
| `form_input` | Set values in form fields |
| `javascript_tool` | Execute JS in page context |

### Content Extraction

| Tool | Purpose |
|------|---------|
| `get_page_text` | Extract article/text content |
| `read_console_messages` | Read browser console |
| `read_network_requests` | Monitor network activity |

---

## Common Patterns

### Initialize Session
```
1. tabs_context_mcp(createIfEmpty=true)
2. Use returned tabId for all subsequent calls
```

### Take Screenshot
```
computer(action="screenshot", tabId=<id>)
```

### Click Element
```
# By coordinates
computer(action="left_click", coordinate=[x, y], tabId=<id>)

# By element reference (from read_page/find)
computer(action="left_click", ref="ref_1", tabId=<id>)
```

### Type Text
```
computer(action="type", text="hello world", tabId=<id>)
```

### Press Keys
```
computer(action="key", text="Enter", tabId=<id>)
computer(action="key", text="cmd+a", tabId=<id>)  # Select all
```

### Scroll
```
computer(action="scroll", coordinate=[500, 400], scroll_direction="down", tabId=<id>)
```

### Wait
```
computer(action="wait", duration=2, tabId=<id>)
```

### Find Elements
```
find(query="submit button", tabId=<id>)
find(query="email input field", tabId=<id>)
```

### Fill Form
```
form_input(ref="ref_5", value="test@example.com", tabId=<id>)
```

### Execute JavaScript
```
javascript_tool(
  action="javascript_exec",
  tabId=<id>,
  text="document.title"
)
```

---

## Google Sheets Specific

### Extract All Visible Cells
```javascript
// Run via javascript_tool
const cells = document.querySelectorAll('[data-cell]');
const data = Array.from(cells).map(c => c.textContent);
JSON.stringify(data);
```

### Get Selected Range
```javascript
// Get currently selected cells in Google Sheets
const selection = document.querySelector('.selection');
selection?.textContent;
```

### Navigate to Cell
```javascript
// Press Ctrl+G or Cmd+G to open "Go to" dialog
// Then type cell reference like "A1"
```

---

## App Store Connect Specific

### Navigate to TestFlight
```
navigate(
  url="https://appstoreconnect.apple.com/apps/{APP_ID}/testflight/testers",
  tabId=<id>
)
```

### Find Add Button
```
find(query="add testers button", tabId=<id>)
```

---

## Error Handling

### Tab Not Found
If you get "tab doesn't exist", call `tabs_context_mcp` to refresh available tabs.

### Element Not Found
1. Take a screenshot to verify page state
2. Wait for page to load: `computer(action="wait", duration=2)`
3. Try scrolling element into view: `computer(action="scroll_to", ref="ref_1")`

### Authentication Required
Browser automation cannot bypass login screens. User must authenticate manually first.

---

## Best Practices

1. **Always get context first**: Call `tabs_context_mcp` before other tools
2. **Screenshot before actions**: Verify page state before clicking
3. **Use wait after navigation**: Pages need time to load
4. **Prefer find over coordinates**: More reliable across screen sizes
5. **Handle errors gracefully**: Check tool results before proceeding
