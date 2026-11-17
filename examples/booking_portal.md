# booking_portal

> **Reader note:** This is an illustrative excerpt of a primer produced by this method. File and class names are renamed, the commit pin is withheld, and rows are trimmed where detail would identify the system, so the pointers cannot be opened. Line ranges are kept from the original. The structure and the claim limits are the point. Note the role line: this primer covers code read in a management role, and its verbs are limited accordingly.

| Field | Value |
|---|---|
| **repo** | withheld |
| **reviewed** | `<pin>` (branch main, one commit; a snapshot), read 2026-11 |
| **role** | managed, from 2024-09 (confirmed by the engineer); led two developers, one per repo; reports writing the original scaffolding and proof of concept (memory, not verifiable from git); the code carries another developer's name and initials in two files; verbs below describe the code, not personal authorship |
| **involvement** | years not stated; dates seen in code span 2024 to 2026 (build file, a comment, a version string) |
| **purpose** | WordPress plugin and child theme that serve online appointment-scheduling pages for several sites configured in code: a React app reads provider and location data from a content site and a directory API, checks availability with an EHR, and embeds the EHR's scheduling widget |
| **stack** | PHP, WordPress, React 18, Vite 5, React Router 6, Sass styles, Python (one script); a whole WordPress install, platform-hosted |
| **files** | 3489 in the tree = 25 deep + 47 skimmed + 7 declared + 3410 unread (3410 skipped on purpose, reasons in coverage) |
| **focus** | the plugin, its front end, the theme, platform files |
| **skills** | code read (managed role, not personal authorship): PHP (deep), WordPress plugin hooks, REST routes, cron (deep), React with React Router (deep), HTTP integration with vendor REST APIs from PHP (deep), Vite build configuration (declared) |

**Coverage**

- deep: the plugin's PHP (11 files), 11 React files (entry, router, handlers, widget, helpers), one Python script, index.html, the theme's functions.php
- skimmed: 45 other React files (`'^wp-content/plugins/booking/frontend/src/.*\.jsx$'`), the theme's editorconfig, the hosting loader
- declared: plugin README, vite config, package.json, theme style.css, root README, .gitignore, hosting config
- unread on purpose: stock and bundled WordPress code 3357 (`'^wp-(admin|includes)/|^wp-content/(themes/(twenty|_s)|plugins/(akismet|hello)|mu-plugins/)'`: 3356 unread, 1 skimmed), 19 stock root files (`'^[^/]+$'`), 6 generated or placeholder files, 29 plugin files (styles, credential-bearing configs, data, other)
- not in the ledger: 524 vendored, 10 build, 559 minified, 254 dist files

**Legend**

- Depth: deep = code read and understood; skimmed = present, not studied; declared = stated in README, notes or commit messages, code unread; none found = looked, nothing there; unread = not opened. (In skills, depth is how deeply the code was read, not proficiency.)
- Source: code = seen in code; declared = stated in project text; memory = from the engineer, not checkable ("confirmed" = the engineer confirmed it); inferred = deduced, not seen.
- May say: deep = built, designed, implemented; skimmed = used, worked with; declared = documented; memory (confirmed) = describe plainly, no outcomes.

**Terms**

- content_client.php = client for the content site, directory_client.php = client for the provider-directory API, ehr_client.php = client for the EHR
- site = one site served by the plugin
- content site = the site the plugin reads from (a separate repository, not read)
- EHR = electronic health record system
- NPI = national provider identifier
- widget = the EHR vendor's embeddable scheduling component
- unused = no live caller or hook
- declared here also covers manifest and config files read as statements

## Facets

| # | Facet | Tag | Depth | Pointer (path @ pin) | Source |
|---|---|---|---|---|---|
| 1 | Language and runtime | PHP; JavaScript (React 18); Python | deep (code), declared (versions) | wp-content/plugins/booking/booking.php lines 10-19; wp-content/plugins/booking/frontend/package.json; wp-content/plugins/booking/frontend/src/fetchMarketData.py lines 1-17 | code, declared |
| 2 | Framework and platform | WordPress plugin: hooks, filters, cron, admin menu | deep | wp-content/plugins/booking/booking.php lines 22-27 (rewrite rule catching every path), 97-108 (title filter), 110-114 and 118-137 (daily cron pulls site data); wp-content/plugins/booking/includes/admin-page.php lines 8-30 (menu, a submenu per site), 32-314, 430-441; wp-content/plugins/booking/templates/booking-template.php lines 2-98 (template_redirect renders an HTML shell and exits for every front-end request; its path check, lines 3-5, is commented out) | code |
| 2b | Framework and platform | Child theme | deep, declared | wp-content/themes/booking_theme/functions.php lines 10-21 (enqueues styles); wp-content/themes/booking_theme/style.css (declared: child of a starter theme) | code, declared |
| 3 | Data layer | WordPress options; no schema | deep | wp-content/plugins/booking/includes/constants.php lines 3-55 (site table); wp-content/plugins/booking/includes/content_client.php lines 35-82 and wp-content/plugins/booking/booking.php lines 118-137 (store site data in one option); wp-content/plugins/booking/includes/api.php lines 324-383 (reads a per-site provider option; no writer for it in the files read) | code |
| 4 | Integrations and APIs | Content site, provider-directory API, EHR, analytics | deep | wp-content/plugins/booking/includes/content_client.php lines 4-32, 35-82; wp-content/plugins/booking/includes/api.php lines 50-193 (read-only proxy), 195-235, 237-270; wp-content/plugins/booking/includes/directory_client.php lines 4-42 (token), 46-95 (provider by NPI), 98-166 (location), 168-206, 208-251 (parsers); wp-content/plugins/booking/includes/ehr_client.php lines 5-62 (practitioner lookup), 77-164 (schedule-days check, called at api.php line 230); wp-content/plugins/booking/frontend/src/components/BookingWidget.jsx lines 15-186 (loads and renders the EHR widget) | code |
| 5 | Architecture and system design | Browser to WordPress proxy to content site; site chosen from host name | deep | wp-content/plugins/booking/templates/booking-template.php lines 2-98 (site from host, query override on staging domains); wp-content/plugins/booking/frontend/src/components/utilities/domain.jsx lines 5-161 (site, staging override, widget version); wp-content/plugins/booking/frontend/src/components/utilities/network.jsx lines 6-109 (calls the proxy); wp-content/plugins/booking/frontend/src/App.jsx lines 1-31 (router setup); wp-content/plugins/booking/frontend/src/components/RouterPathing.jsx lines 9-105 (14 routes) | code |
| 5b | Architecture and system design | Unused or disabled code | deep, skimmed | Unused at this pin: wp-content/plugins/booking/includes/shortcode.php lines 6-44 (never loaded); no-caller code in four other PHP files; wp-content/plugins/booking/booking.php lines 47-93 (hook commented out); 8 unreferenced React files. Intent not recorded; the engineer does not recall | code |
| 6 | Front end and UX | React single-page app: provider, specialty and a third route group | deep, skimmed | wp-content/plugins/booking/frontend/src/components/ProviderHandler.jsx lines 14-106; wp-content/plugins/booking/frontend/src/components/ProviderV2.jsx lines 10-146; wp-content/plugins/booking/frontend/src/components/SpecialtyHandler.jsx lines 18-187; 45 other components skimmed | code |
| 7 | Hosting and delivery | Platform-hosted WordPress; one snapshot; Vite build flags | declared, deep | Hosting config file; README.md; wp-content/plugins/booking/frontend/vite.config.js (build flags); package.json. Comments hold platform commands naming environments (booking.php lines 31, 49, 117). No tags or branches | code, declared |
| 8 | Testing | none found | none found | No test folder or CI config in the plugin or root lists; package.json has a lint script only. Manual helpers: wp-content/plugins/booking/includes/admin-page.php lines 521-538 | code |
| 9 | Observability, performance, operations | Error logging; daily cron; analytics tags | deep | wp-content/plugins/booking/includes/api.php lines 50-193 (logs failed upstream calls); wp-content/plugins/booking/booking.php lines 118-137 (cron task) | code |
| 10 | Security and data handling | Allowlisted proxy; admin screen gated by a capability | deep | wp-content/plugins/booking/includes/api.php lines 50-193 (allowlisted routes and parameters, https required, redirects off, upstream credentials server-side); wp-content/plugins/booking/includes/admin-page.php lines 8-30 (admin menu needs manage_options), 327-335 (masked password field), 377-426 (blank credential fields keep the old value) | code |
| 11 | Problem and solution | see entry below | deep | see below | code |
| 12 | Business context and scale | Online scheduling across several sites; later retired | memory (confirmed; some items hedged) | Retired after use; no outcomes recorded | memory |

## Problem and solution entries (facet 11)

**A. One plugin serving many sites**
- **Context:** several sites configured in one plugin (wp-content/plugins/booking/includes/constants.php lines 3-55).
- **Options considered:** not recorded.
- **Decision:** site chosen from the request host, with a staging override; data through a server-side proxy and one cached site option (code).
- **Consequences:** none recorded.
- **Pointer:** wp-content/plugins/booking/templates/booking-template.php lines 2-98; wp-content/plugins/booking/includes/api.php lines 50-193
- **Source:** code
