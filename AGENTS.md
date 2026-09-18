# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Joget DX9 marketplace plugin: a custom `DataListAction` (`org.joget.marketplace.FormUpdateProcessToolDatalistAction`) that runs against selected rows in a Joget Data List and, per selected row, can:

1. Update a record's form data via a popup form,
2. Execute a configured Joget process tool (`ApplicationPlugin`), and/or
3. Delegate to another configured `DataListAction`.

It builds as an OSGi bundle (`packaging: bundle`, Felix bundle plugin) that gets uploaded into a running Joget DX9 server as a plugin `.jar`.

## Build & test

Requires JDK 8/17-compatible toolchain and a Maven settings file pointing at Joget's Maven repo (the `org.joget:wflow-core` and `org.joget:wflow-enterprise-plugins` dependencies are `7.0-SNAPSHOT` and are not on Maven Central).

```bash
mvn clean package
```

- Output bundle: `target/form-update-process-tool-datalist-action-7.0.9.jar` — upload this via the Joget admin console's Manage Plugins screen to install/update the plugin.
- There is no `src/test` directory and no unit tests currently exist, despite `maven-surefire-plugin` being configured to run in the `integration-test` phase. There is no way to test this plugin's behavior outside of a running Joget DX9 instance — verification is manual, through the Joget admin console (add the plugin to a Data List, configure a popup form / process tool, run it against real records).
- To bump the plugin version, update the `<version>` in `pom.xml` and the `getVersion()` return value in `FormUpdateProcessToolDatalistAction.java` together.

## Architecture

Everything lives in two Java classes plus plugin metadata:

- [`Activator.java`](src/main/java/org/joget/marketplace/Activator.java) — OSGi `BundleActivator` that registers `FormUpdateProcessToolDatalistAction` as a service on bundle start. Boilerplate; only touch if adding another plugin class to register.
- [`FormUpdateProcessToolDatalistAction.java`](src/main/java/org/joget/marketplace/FormUpdateProcessToolDatalistAction.java) — the entire plugin. Extends `DataListActionDefault` and implements `DataListPluginExtend`.
- [`properties/FormUpdateProcessToolDatalistAction.json`](src/main/resources/properties/FormUpdateProcessToolDatalistAction.json) — declares the admin-configurable properties shown in the Joget "Edit Datalist Action" UI (popup form selector, process tool selector, additional datalist action selector, HTML script, delay, debug toggle, etc). Property names here must match the string keys read via `getPropertyString(...)` / `getProperty(...)` in the Java class.
- [`templates/*.ftl`](src/main/resources/templates/) — FreeMarker templates rendered by `getHTML()`: `FormUpdateProcessToolDatalistAction.ftl` (plain action button, no popup form) vs `FormUpdateProcessToolDatalistActionWithForm.ftl` (renders the embedded popup form when `popupFormId` is configured).
- [`messages/FormUpdateProcessToolDatalistAction.properties`](src/main/resources/messages/FormUpdateProcessToolDatalistAction.properties) — i18n strings looked up via `AppPluginUtil.getMessage(...)`.

### Execution flow (`executeAction`)

Called by Joget when the bulk action button is submitted from a Data List. Only proceeds on POST. For each selected row key:

1. **Popup form update** (if `popupFormId` is configured and the popup form's JSON payload was submitted as the `bulkcompleteformdata` request parameter): resolves the real process/record ID via `appService.getOriginProcessId(recordId)`, builds a `FormData` via `getFormData(...)`, then runs `formService.recursiveExecuteFormStoreBinders(...)`. Optionally runs `FormUtil.executePostFormSubmissionProccessor(...)` afterward if `popupFormPostProcessing` is enabled.
2. **Process tool** (if `processTool` property has a `className`): reflectively loads the `ApplicationPlugin` via `pluginManager`, builds a mock `WorkflowAssignment` for the row's record ID, merges default properties, replaces `@recordId@` / hash variable placeholders in the tool's configured properties (`replaceValueHashMap`), then calls `appPlugin.execute(...)`.
3. Optional `delay` (seconds) sleep between rows — Joget process tools can be async/eventually-consistent, so this gives downstream effects time to settle before the next row.

After the row loop, if an `additionalDataListAction` is configured, this plugin's own properties are merged with that action's properties and execution is delegated to it (`datalistActionPlugin.executeAction(...)`) — this lets admins chain another built-in/marketplace Data List action after this one runs.

### `getFormData()` — why it clones the existing row

`getFormData(json, recordId, processId, form)` builds the single-row `FormRowSet` that gets handed to `formService.recursiveExecuteFormStoreBinders()`. It seeds the row from the record's **existing** data (loaded via `form.getLoadBinder()`) before overlaying the popup form's submitted JSON fields on top — not just a bare row with only what the popup form happened to submit. This matters because:

- The admin-configured popup form is normally a *subset* of the real form's fields.
- Some `FormStoreBinder`s write every field the row object has rather than doing a true per-column SQL update, so an unseeded row would silently blank every column the popup form didn't include.
- Audit-trail-aware store binders (e.g. `org.joget.marketplace.WorkflowFormBinderWithAuditTrail`) diff the "before" (load binder) row against the "after" (store) row and can NPE if an expected field is simply absent.

The existing row is **cloned** (`FormRow` extends `java.util.Properties`; `clone()` is `Hashtable#clone()`) before being overlaid — the same row instance is already passed to `formData.setLoadBinderData(...)` as the "before" snapshot, so mutating it in place would corrupt that snapshot and defeat any before/after diffing binder. Falls back to a bare empty row if the form has no load binder or no existing row is found. See git history / [PR_DESCRIPTION.md](PR_DESCRIPTION.md) for the incident this fixed.

Within `getFormData`, the submitted JSON's `FormUtil.PROPERTY_TEMP_REQUEST_PARAMS` and `FormUtil.PROPERTY_TEMP_FILE_PATH` keys are handled specially (request parameters and uploaded temp files respectively, the latter copied into a new UUID-named path via `FileManager`); all other keys are set as plain row properties.

### Popup form embedding (`getHTML` / `getSelectedFormJson`)

When a popup form is configured, `getHTML()` renders `FormUpdateProcessToolDatalistActionWithForm.ftl`, which embeds the form's element JSON (from `getSelectedFormJson`). That JSON has its configured load/store binders swapped out for `org.joget.plugin.enterprise.JsonFormBinder` (so the popup form round-trips through JSON rather than touching the database directly) and is encrypted (`SecurityUtil.encrypt`) plus nonce-protected (`SecurityUtil.generateNonce`) before being embedded in the page — the real store binder is only invoked later, server-side, in `executeAction`/`getFormData` against the real `Form` object.

## Conventions to preserve

- Target/source compatibility is Java 1.7 per `pom.xml` — avoid syntax newer than that (diamond operator on anonymous classes, `var`, etc.) even though modern JDKs are used to build.
- Uses raw `Map`/`List` types throughout (no generics) to match the surrounding Joget SDK API surface and the existing code style — keep new code consistent rather than introducing generics inconsistently.
- Debug logging is gated behind the `debug` plugin property (`LogUtil.info` calls guarded by `if (debugMode)`) rather than always-on logging.
- `Import-Package` in `pom.xml`'s bundle-plugin config explicitly lists every `org.joget.*`/`javax.servlet`/`org.osgi` package this plugin depends on at OSGi load time — if you add an import from a new Joget package, add it to that `Import-Package` list too, or the bundle will fail to resolve at runtime in Joget even though it compiles fine.
