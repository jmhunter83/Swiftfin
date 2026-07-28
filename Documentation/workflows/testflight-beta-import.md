# TestFlight Beta Tester Import Workflow

> **⚠️ ARCHIVED**: This workflow was used during Reefy's public beta program (ended January 17, 2026). Reefy is now available on the Apple App Store in 175 countries. This document is preserved for historical reference and potential future beta programs.

---

Automated workflow using Claude Code's Chrome tools to extract beta tester emails from Google Sheets and import them into TestFlight.

## Overview

This workflow automates the process of:
1. Reading beta signup data from a Google Sheet
2. Extracting and formatting tester information
3. Importing testers into App Store Connect TestFlight

## Prerequisites

- Claude Code with Chrome MCP tools enabled
- Access to the Google Sheet containing signups
- App Store Connect access with TestFlight permissions
- Chrome browser with Claude extension installed

## Source Data

**Google Sheet**: Reefy Beta/TestFlight Sign-up (Responses)
- URL: `https://docs.google.com/spreadsheets/d/1e5xx_9UfzJJkgUM31eTLqQqnxr-VH4bQMSgKTw500bY/edit`
- Columns: Timestamp, Email Address, First Name, Last Name

**TestFlight**: App Store Connect
- URL: `https://appstoreconnect.apple.com/apps/{APP_ID}/testflight/testers`

---

## Workflow Steps

### Step 1: Initialize Browser Context

```
Use: mcp__claude-in-chrome__tabs_context_mcp
Parameters: { "createIfEmpty": true }
```

This establishes the browser session and returns available tabs.

### Step 2: Navigate to Google Sheet

```
Use: mcp__claude-in-chrome__navigate
Parameters: {
  "url": "https://docs.google.com/spreadsheets/d/1e5xx_9UfzJJkgUM31eTLqQqnxr-VH4bQMSgKTw500bY/edit",
  "tabId": <tab_id>
}
```

### Step 3: Extract Data from Sheet

**Option A: Using JavaScript extraction**
```
Use: mcp__claude-in-chrome__javascript_tool
Parameters: {
  "action": "javascript_exec",
  "tabId": <tab_id>,
  "text": "
    // Get all rows from the active sheet
    const rows = document.querySelectorAll('tr');
    const data = [];
    rows.forEach((row, index) => {
      if (index === 0) return; // Skip header
      const cells = row.querySelectorAll('td');
      if (cells.length >= 4) {
        data.push({
          email: cells[1]?.textContent?.trim(),
          firstName: cells[2]?.textContent?.trim(),
          lastName: cells[3]?.textContent?.trim()
        });
      }
    });
    JSON.stringify(data.filter(d => d.email));
  "
}
```

**Option B: Using page reading**
```
Use: mcp__claude-in-chrome__read_page
Parameters: {
  "tabId": <tab_id>,
  "filter": "all"
}
```

Then parse the accessibility tree to extract cell contents.

### Step 4: Format for TestFlight Import

TestFlight CSV format requires:
```csv
First Name,Last Name,Email
John,Doe,john@example.com
```

Generate CSV content:
```javascript
const csv = ['First Name,Last Name,Email'];
testers.forEach(t => {
  csv.push(`${t.firstName},${t.lastName},${t.email}`);
});
const csvContent = csv.join('\n');
```

### Step 5: Navigate to TestFlight

```
Use: mcp__claude-in-chrome__navigate
Parameters: {
  "url": "https://appstoreconnect.apple.com/apps/<APP_ID>/testflight/testers",
  "tabId": <tab_id>
}
```

### Step 6: Import Testers

**Manual steps required** (TestFlight doesn't support direct automation for security):

1. Click "+" button to add testers
2. Select "Import from CSV" option
3. Upload the generated CSV file
4. Review and confirm import

**Alternative: Individual Addition**
For smaller batches, use the "Add Individual Testers" flow:
```
Use: mcp__claude-in-chrome__find
Parameters: {
  "query": "add tester button",
  "tabId": <tab_id>
}
```

---

## Complete Automation Script

```python
# Pseudocode for full workflow

# 1. Get browser context
context = tabs_context_mcp(createIfEmpty=True)
tab_id = context.availableTabs[0].tabId

# 2. Navigate to Google Sheet
navigate(url=SHEET_URL, tabId=tab_id)
wait(2)

# 3. Extract tester data
screenshot(tabId=tab_id)  # Capture for verification
data = javascript_tool(
    action="javascript_exec",
    tabId=tab_id,
    text=EXTRACTION_SCRIPT
)

# 4. Parse and validate
testers = json.loads(data)
valid_testers = [t for t in testers if validate_email(t.email)]

# 5. Generate CSV
csv_content = generate_csv(valid_testers)
save_to_file(csv_content, "~/Downloads/testflight_import.csv")

# 6. Navigate to TestFlight
navigate(url=TESTFLIGHT_URL, tabId=tab_id)
wait(2)

# 7. Prompt user for manual import
print(f"CSV saved. Please import {len(valid_testers)} testers manually.")
```

---

## TestFlight Tester Statuses

After import, testers will show one of these statuses:

| Status | Meaning |
|--------|---------|
| **Invited** (yellow) | Email sent, awaiting acceptance |
| **Accepted** (green checkmark) | Tester accepted, can install builds |
| **No Builds Available** (red) | Tester needs to be added to a group with builds |
| **Expired** | Invitation expired (90 days) |

### Troubleshooting "No Builds Available"

Testers must be in a **group** that has access to builds:

1. Go to TestFlight > Groups
2. Create an External Testing group (e.g., "Beta Testers")
3. Add testers to the group
4. Submit a build for external testing
5. Once approved, testers receive build access

---

## Data Validation

Before import, validate:

```javascript
function validateEmail(email) {
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return re.test(email);
}

function validateTester(tester) {
  return {
    valid: validateEmail(tester.email) &&
           tester.firstName?.length > 0,
    email: tester.email,
    issues: []
  };
}
```

---

## Limitations

1. **Authentication**: Cannot automate App Store Connect login (security)
2. **CSV Upload**: File upload requires manual interaction
3. **Rate Limits**: TestFlight has daily invitation limits
4. **Build Approval**: External testing requires Apple review

---

## Related Files

- Google Sheet: Beta signup form responses
- CSV Export: `~/Downloads/testflight_import.csv`
- TestFlight: App Store Connect portal

## Last Updated

2026-01-15
