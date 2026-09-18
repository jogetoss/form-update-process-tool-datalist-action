# Seed audit-trail-safe form data, forward userview key to popup forms, add repo docs

## Summary
- Seed `getFormData()`'s row from existing data (cloned) so partial popup-form
  submits don't blank columns or break audit-trail store binders.
- Forward the current userview's key to the popup form as a `key` request
  parameter, so form elements can read it back via `#requestParam.key#`.
- Add `AGENTS.md` (with a `CLAUDE.md` symlink) documenting the plugin's build
  process and architecture for future contributors/AI agents.

## Change 1: Seed `getFormData()`'s row from existing data

### Problem
`FormUpdateProcessToolDatalistAction.getFormData()` built the row passed to
`FormService#recursiveExecuteFormStoreBinders()` from *only* whatever fields
the admin-configured popup form happened to submit — never the record's
existing data.

That breaks in two ways when the popup form has fewer fields than the real
Form (the normal case, since it's configured independently):

1. **Audit-trail-aware store binders throw NPEs.** A binder like
   `org.joget.marketplace.WorkflowFormBinderWithAuditTrail` diffs the
   "before" (load binder) row against the "after" (store) row field-by-field,
   and reads a configured "remarks" field straight off the store row. If the
   popup form doesn't include that field, it's simply absent from the row —
   `Map.get(...)` returns `null`, and the binder's
   `ConcurrentHashMap`/`Hashtable`-backed map rejects the `null` value on
   `put()`.
2. **Selective updates aren't actually selective**, depending on the
   configured `FormStoreBinder`. A binder that writes every field the row has
   (rather than a true per-column `UPDATE ... SET x=?`) silently blanks
   every column the popup form didn't submit.

### Fix
Before overlaying the popup form's submitted JSON, seed the row from the
record's existing data, loaded via the Form's own load binder:

- Load the existing `FormRowSet` via `form.getLoadBinder()` and call
  `formData.setLoadBinderData(...)` as before (unchanged behavior for the
  "before" snapshot).
- Start the row to be populated from a **clone** of the existing row
  (`FormRow` extends `java.util.Properties`, so `clone()` is
  `Hashtable#clone()` — a standard shallow copy), then overlay the submitted
  fields on top.
- Cloning is required, not optional: the existing row is the *same object*
  just handed to `setLoadBinderData()` as the "before" snapshot. Mutating it
  in place would corrupt that snapshot out from under any binder reading it
  — the diff would compare the row against itself post-mutation and never
  detect a change, silently defeating audit-trail binders.
- Falls back to the previous bare/empty-row behavior if the Form has no load
  binder or no existing row is found for `recordId` — this action only ever
  runs against selected existing Data List rows, so that's not expected, but
  `getFormData()` stays as forgiving of it as before (catches everything,
  returns `null` on failure) rather than newly failing a bulk-action item.

Same underlying pattern (and same fix) already applied in
`planner-frappe-menu`/`planner-kanban-menu`'s `saveTaskFieldValues()`, which
have the identical issue.

## Change 2: Forward userview key to popup form

### Problem
Popup forms opened from this action have no way to know which userview (and
which keyed/embedded userview session) they were launched from. A Custom
HTML field bound to `#requestParam.key#` — used, for example, to display or
reuse the current userview session's key — always rendered blank.

### Fix
Userview URLs end in `.../{menuId}/{userviewKey}` (e.g.
`.../userview/frappeGantt/v/cloud/EA9FBB19046C44DE3677B50409A33590` — the
last segment is the menu id, the second-to-last is the userview key). In
`FormUpdateProcessToolDatalistActionWithForm.ftl`, a new
`fuptda_getUserviewKey()` helper extracts that second-to-last path segment
from `window.location.pathname` client-side, and it's added to the
`JPopup.show(...)` params as `key` whenever present — so it's posted to the
popup form's `/form/embed` endpoint as a normal request parameter and
resolves via the `#requestParam.key#` hash variable.

## Change 3: Add `AGENTS.md` repo guidance

Adds `AGENTS.md` (read by Claude Code and other coding agents), covering how
to build the plugin (`mvn clean package`, required JDK/Maven-repo setup, lack
of automated tests), the two-class plugin architecture, the `executeAction`
flow, the `getFormData()` row-seeding rationale above, and the popup-form
JSON-binder-swap/encryption mechanism in `getHTML()`. `CLAUDE.md` is a
symlink to `AGENTS.md` so both tools pick up the same guidance.

## Testing
- `mvn clean package` (JDK 17) — `BUILD SUCCESS`.
- No automated tests in this module; recommend manually verifying:
  1. A popup form update still writes correctly.
  2. A popup form with a subset of fields no longer blanks the omitted
     columns.
  3. A `WorkflowFormBinderWithAuditTrail`-configured form no longer NPEs on
     a "remarks"-only-in-real-form scenario.
  4. Opening the popup form from a keyed userview URL shows the correct
     userview key in a `#requestParam.key#`-bound field.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
