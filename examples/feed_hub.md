# feed_hub

> **Reader note:** This is an illustrative excerpt of a primer produced by this method. File and class names are renamed, the commit pin is withheld, and rows are trimmed where detail would identify the system, so the pointers cannot be opened. Line ranges are kept from the original. The structure and the claim limits are the point. Note the role line: this primer covers code read in a management role, and its verbs are limited accordingly.

| Field | Value |
|---|---|
| **repo** | withheld |
| **reviewed** | `<pin>` (main, single commit, no tags), read 2026-11 |
| **role** | managed (confirmed, from 2024-09); a team of web developers that included the engineer (memory, confirmed); when the code was written is not determinable from git; verbs below describe the code, not personal authorship |
| **involvement** | not determinable from git (one commit, an import) |
| **purpose** | Drupal 10 site that pulls scheduling data live from an outside system, builds provider and location records from stored data, lets internal teams override it, and serves it as JSON and XML feeds and Excel and CSV exports |
| **stack** | PHP 8.2, Drupal 10.5, Drush, Guzzle, Composer; nodes, taxonomy terms, Drupal state and cache |
| **files** | 108 in the tree = 14 deep + 12 skimmed + 19 declared + 63 unread (15 of them skipped on purpose: data file, config, stock template, empty file, unused config copies) |
| **focus** | vendor services, record matching, exports, feeds, scheduling comparison, module hooks, plus the data refresh and override logic |
| **skills** | PHP (deep), Drupal hooks and services (deep), Drupal queue workers and cron (deep), Drupal REST resource plugins (deep), Guzzle HTTP client calls (skimmed), Levenshtein matching (deep), CSV and Excel import and export (skimmed), Composer packaging (declared) |

**Coverage**

- deep: hooks, cron pipeline, provider and location sync, feed and content-matching resources, a CSV parser, export service
- skimmed: vendor services, export form and service, 3 REST resources in part, dead worker
- skipped: one data file, `private/` (6), 2 hosting settings, one resource, `config/sync/` (5)
- unread: 6 settings forms, 4 resources, 1 queue worker, hosting and core stubs

**Legend**

- Depth: deep = code read and understood; skimmed = present, not studied; declared = stated in README, notes or commit messages, code unread; none found = looked, nothing there; unread = not opened. (In skills, depth is how deeply the code was read, not proficiency.)
- Source: code = seen in code; declared = stated in project text; memory = from the engineer, not checkable ("confirmed" = the engineer confirmed it); inferred = deduced, not seen.
- May say: deep = built, designed, implemented; skimmed = used, worked with; declared = documented; memory (confirmed) = describe plainly, no outcomes.

**Terms**

- source system = the outside scheduling system the site reads from
- directory = a provider-profile service whose API is retired in code
- NPI = national provider identifier
- export form = the admin export screen
- override = a staff-set field that survives refresh

## Facets

Each pointer is at the pin.

| # | Facet | Tag | Depth | Pointer (path) | Source |
|---|---|---|---|---|---|
| 1 | Language and runtime | PHP 8.2; Drupal 10 | declared | composer.json (platform pin 8.2.29, `drupal/core-recommended ^10`); composer.lock (core 10.5.1); hosting upstream file (`php_version: 8.2`) | declared |
| 2 | Framework and platform | Drupal hooks, services, cron, routes | deep, declared | web/modules/custom/feed_hub/feed_hub.module lines 14-17 (cron), 40-81 (node presave); web/modules/custom/feed_hub/src/Plugin/Action/ProcessProviderAction.php lines 72-90 (bulk action, part); declared: feed_hub.routing.yml, feed_hub.services.yml, composer.json (12 contrib modules) | code, declared |
| 3 | Data layer | Drupal nodes, taxonomy terms, state, cache | deep | web/modules/custom/feed_hub/src/Service/SourceService.php lines 199-223, 238-289 (get-or-create terms); web/modules/custom/feed_hub/src/Plugin/rest/resource/ProviderResource.php lines 142-315 (24-hour cache with tags) | code |
| 4 | Integrations and APIs | Source system API; patient scheduling API | deep, skimmed | web/modules/custom/feed_hub/src/Service/SourceService.php lines 125-197 (schedule days); web/modules/custom/feed_hub/src/Service/PlatformService.php lines 91-172 (part), 479-520 (put, part); web/modules/custom/feed_hub/src/Service/CronService.php lines 63-142 (scheduled refresh) | code |
| 4b | Integrations and APIs | Feeds out: REST resource plugins and one XML route | deep, skimmed | web/modules/custom/feed_hub/src/Plugin/rest/resource/ProviderResource.php lines 142-315; web/modules/custom/feed_hub/src/Plugin/rest/resource/ContentBlockResource.php lines 129-353; web/modules/custom/feed_hub/src/Plugin/rest/resource/LocationResource.php lines 116-200 (part). 9 resource plugins in code; 5 have config in the tree, the rest are not shown enabled | code, declared |
| 4c | Integrations and APIs | Directory API, retired | deep | web/modules/custom/feed_hub/src/Service/DirectoryService.php lines 55-57, 102-135 (calls return stub errors); gates: CronService.php lines 103-110, ProcessProviderDataService.php lines 70-90, 202-209. Live calls are dead (row 5b); stored data is still read by the feeds | code |
| 5 | Architecture and system design | Staged cron pipeline; override-preserving refresh | deep | web/modules/custom/feed_hub/src/Service/CronService.php lines 63-142 (source IDs, then provider nodes in two queues, then locations, by state flags); web/modules/custom/feed_hub/src/Service/ProcessProviderDataService.php lines 411-473 (keeps custom specialties and visit-type exclusions on refresh), 374-409 (ID reconcile) | code |
| 5b | Architecture and system design | Dead and unused code | skimmed, deep | Dead or unused code is indexed in a side file, not shown here | code |
| 5c | Architecture and system design | Record matching | deep, skimmed | web/modules/custom/feed_hub/src/FeedHubCommon.php lines 405-413 (`fuzzyMatch`: edit distance as a percentage); web/modules/custom/feed_hub/src/Service/ExportService.php lines 625-800 (NPI, then name over 90, then name without suffix; a later stage unread; part, dead; `fuzzyMatch` is called only here, so never "runs"); web/modules/custom/feed_hub/src/Plugin/QueueWorker/LocationQueueWorker.php lines 212-259 (rule-based address match) | code |
| 6 | Front end and UX | Admin screens with live source options and action buttons | deep, skimmed | web/modules/custom/feed_hub/feed_hub.module lines 86-206 (limits exclusion choices to visit types the source offers now), 208-258; web/modules/custom/feed_hub/src/Form/ExportForm.php lines 76-240 (export groups, part) | code |
| 7 | Hosting and delivery | Hosting-platform upstream; one commit, no tags | declared | Hosting config files; composer.json (`type: project`, no version, path repository, symlinks for a config) | declared |
| 8 | Testing | none found | none found | Looked in the tree, composer.json scripts and module README; no test folders or CI file. README lists two manual recovery recipes | code, declared |
| 9 | Observability, performance, operations | Logger channel, state logs, fail-safe | deep | web/modules/custom/feed_hub/src/Service/SourceService.php lines 415-531 (on a source error, clears the department ID field, lines 499-504; admin form only, not cron); web/modules/custom/feed_hub/src/Service/CronService.php lines 63-142 (logs per stage); `drush` recipes in comments, CronService.php lines 57-61 | code |
| 10 | Security and data handling | trimmed from this excerpt | not shown | withheld | not shown |
| 11 | Problem and solution | see entry | deep | see below | code, memory |
| 12 | Business context and scale | Used across the organization's sites; internal teams override | memory (confirmed) | Used by every site; no outcomes recorded | memory |

## Problem and solution entries (facet 11)

**A. Raw source data that is understandable, dependable and overridable**
- **Context:** provider scheduling data comes from an outside system; internal teams needed to correct it without losing the corrections on the next refresh (memory, confirmed).
- **Options considered:** not recorded in code or by the engineer.
- **Decision:** refresh from the source on a schedule and store the result as terms and node fields; re-add custom-origin specialties and keep visit-type exclusions the source still offers on each run; scheduling flags are editor-set fields the refresh leaves alone; show editors only the options the source offers now; serve stored values through a cached feed and a content feed with weights and a debug breakdown.
- **Consequences:** overrides are inspectable in code. Outcomes are not recorded.
- **Pointer:** web/modules/custom/feed_hub/src/Service/ProcessProviderDataService.php lines 411-473; web/modules/custom/feed_hub/feed_hub.module lines 86-206; web/modules/custom/feed_hub/src/Plugin/rest/resource/ContentBlockResource.php lines 358-785
- **Source:** code, memory (confirmed)
