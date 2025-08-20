---
description: Force fresh file read and invalidate all cached understanding
---

CRITICAL: The user has made external changes and I must completely refresh my understanding of the file.

**MANDATORY STEPS:**
1. **INVALIDATE** all previous assumptions about file contents - treat as if I've never seen this file before
2. **IDENTIFY** the file from conversation history (most recently edited/discussed file)
3. **READ** the file using the Read tool - this is REQUIRED, not optional
4. **COMPARE** current state against my last known state and report specific changes
5. **VERIFY** my new understanding is correct before proceeding with any further edits

**CRITICAL RULES:**
- I must NOT rely on any cached/remembered file state
- I must NOT make assumptions about unchanged portions
- I must NOT proceed with edits until I've confirmed current state
- If unsure about any changes, I must ask for clarification

**FAILURE MODE TO AVOID:** Making edits based on outdated file state, especially adding duplicate code that was already removed.

After completing the re-read, acknowledge: "File state refreshed - ready to proceed with current version."

If additional instructions follow '/reread', execute them only after completing this refresh process.