# variant_forms

> **Reader note:** This is an illustrative excerpt of a primer produced by this method. File and class names are renamed and the commit pin is withheld, so the pointers cannot be opened. Line ranges are kept from the original. The structure and the claim limits are the point.

| Field | Value |
|---|---|
| **repo** | withheld |
| **reviewed** | `<pin>` (branch beta), read 2026-11 |
| **role** | wrote, 2022 (confirmed, sole author) |
| **involvement** | 2022-08 to 2022-09 (12 commits) |
| **purpose** | Drupal module that serves variants of a form from one site and renders and collects them on other sites over REST; proof of concept, never in production; much unused or disabled (row 5b) |
| **stack** | PHP (version not determinable), Drupal 8/9, Webform module, Guzzle, Composer |
| **files** | 42 in the tree = 14 deep + 6 skimmed + 20 declared + 2 unread (2 skipped on purpose: empty css and js files) |
| **focus** | form sync, REST resources, variant plugin and admin forms, settings |
| **skills** | PHP (deep), Drupal Form API (deep), Drupal REST resource plugins (deep), Webform variant plugin extension (deep), Drupal route alteration and event subscribers (deep), Guzzle HTTP client calls (deep), Composer packaging (declared) |

**Coverage**

- deep: 14 files (11 PHP, module, install, one template)
- skimmed: 4 unreferenced form classes, one example block, one demo config export
- declared: README, CHANGELOG, dev notes, 7 root manifest files, config YAML
- skipped: empty css and js

**Legend**

- Depth: deep = code read and understood; skimmed = present, not studied; declared = stated in README, notes or commit messages, code unread; none found = looked, nothing there; unread = not opened. (In skills, depth is how deeply the code was read, not proficiency.)
- Source: code = seen in code; declared = stated in project text; memory = from the engineer, not checkable ("confirmed" = the engineer confirmed it); inferred = deduced, not seen.
- May say: deep = built, designed, implemented; skimmed = used, worked with; declared = documented; memory (confirmed) = describe plainly, no outcomes.

**Terms**

- webform = a Drupal form-builder module
- variant = a named override of a webform's settings or elements
- REST resource = a Drupal plugin exposing an endpoint
- client, server, dev = site modes (render from upstream, serve locally, both)
- site group = a set of sites sharing one configuration
- table-sync = disabled methods that mirrored variant rows to a table and REST
- pin = the commit read

## Facets

| # | Facet | Tag | Depth | Pointer (path @ pin) | Source |
|---|---|---|---|---|---|
| 1 | Language and runtime | PHP; Drupal 8/9 | deep (code), declared (core range) | src/FormsCommon.php; variant_forms.info.yml (`core_version_requirement: ^8 \|\| ^9`) | code, declared |
| 2 | Framework and platform | Drupal routes, services, event subscriber, hooks | deep, declared | Declared: variant_forms.routing.yml lines 1-17; variant_forms.services.yml lines 1-13. Code: src/Routing/RouteSubscriber.php lines 16-72 (alterRoutes: delete form swapped, add route retitled); variant_forms.module lines 57-60, 106-110 | code, declared |
| 2b | Framework and platform | Webform variant plugin extension | deep | src/Plugin/WebformVariant/SiteOverrideWebformVariant.php lines 39-74 (create), 88-137 (buildConfigurationForm: site-list checkboxes, local alias field), 142-168 (validateConfigurationForm: live, to-do warning); lines 173-177 unused | code |
| 3 | Data layer | REST registration endpoints; table never created at this pin | deep | src/Plugin/rest/resource/RegistrationsRestResource.php lines 176-193, 206-227, 243-260 (insert, update, delete). The only schema function is disabled, so these endpoints depend on a table created outside this repo (variant_forms.install lines 30-111 unused). Settings saved to site config (src/Form/SettingsForm.php lines 184-208) | code |
| 4 | Integrations and APIs | REST resources exposed; Guzzle client to the server site | deep | src/Plugin/rest/resource/FormsRestResource.php lines 140-148 (get), 159-171 (post), 328-344 (createWebformSubmission). Client calls: src/FormsCommon.php lines 190-235, 277-325, 331-372; Basic auth from config | code |
| 5 | Architecture and system design | Client, server and dev modes; remote form rendered locally | deep, declared | src/Form/DynamicWebForm.php lines 62-202 (__construct: mode switch; a client shows a variant only if its own site group is ticked on it and it is enabled, else access denied), 233-332 (buildForm; live lines 233-247, the rest commented out), 351-363 (submitForm posts upstream). Declared: a commit message, "going headless" | code, declared |
| 5b | Architecture and system design | Disabled or unused code | deep, skimmed | Unused at this pin: src/FormsCommon.php lines 490-785 (table-sync methods); two controllers with no route; disabled methods in several files; 4 unreferenced form classes (skimmed). Intent not recorded; the engineer does not recall | code |
| 6 | Front end and UX | Form API admin screens; variant list with remote-view link | deep | src/Form/EntityVariantsForm.php lines 79-148 (adds Remote Sync column, View Remote link); src/Form/SettingsForm.php lines 74-168; one Twig summary template lines 1-16 | code |
| 7 | Hosting and delivery | Composer package; config import | declared | composer.json: type `drupal-custom-module`, empty require, no version field. Three branches | declared |
| 8 | Testing | none found | none found | Looked in the tree, composer.json and README. A commit message says client testing went well (declared) | code, declared |
| 9 | Observability, performance, operations | Logger channel; error logging | deep, declared | Declared: variant_forms.services.yml lines 2-4. Code: src/FormsCommon.php lines 190-235, 277-325, 331-372, 391-452 (return codes); variant_forms.install lines 116-129 (requirements hook returns a random number) | code, declared |
| 10 | Security and data handling | REST auth set per method in config; checks in the form constructor | deep, declared | src/Form/DynamicWebForm.php lines 62-202 (login required in dev and server modes); declared in the module's REST config: GET accepts basic_auth or cookie, other enabled methods basic_auth only | code, declared |
| 11 | Problem and solution | see entry below | deep, declared | see below | code, declared, memory |
| 12 | Business context and scale | Planned multi-site form catalog; development only | memory (confirmed; some items hedged) | Proof of concept, never in production | memory |

## Problem and solution entries (facet 11)

**A. One form, different versions per site, kept in one place**
- **Context:** per-site variants of a central webform (declared: dev notes).
- **Options considered:** Webform variants, or a config-revisions module (declared); rationale: memory, hedged.
- **Decision:** Webform variants, extended with a plugin that lists target sites; clients fetch it over REST and render locally (code).
- **Consequences:** table-sync disabled at the pin (row 5b); no outcome recorded.
- **Pointer:** src/Plugin/WebformVariant/SiteOverrideWebformVariant.php lines 88-137; the mode switch in row 5
- **Source:** code, declared, memory (hedged)
