# PHP and Drupal notes

Entry points: routes in `*.routing.yml` (a controller is reached through its route; also check `route_callbacks`, and grep the class name for other callers), `*.services.yml`, `*.permissions.yml`, hooks in `*.module` and `*.install` (`hook_install`, `hook_update_N`, `hook_uninstall`, `hook_cron`), event subscribers, Drush commands, and plugin classes (REST resources, blocks, queue workers, fields). For a plugin the class is the entry point; a config file such as `rest.resource.*.yml` only enables it.

List top-level route names, commented ones included, in a routing file (not services): `grep -nE '^(# ?)?[A-Za-z0-9_.-]+:[[:space:]]*$' file.routing.yml`. It misses quoted names and trailing comments, so read the file raw.

Comment-stripped listing for PHP and JavaScript, for navigation only: `awk '!/^[[:space:]]*(\/\/|\*|\/\*)/ && NF {print NR": "$0}' file`. It hides live lines that start with a comment marker.

Names that mark code as old, disabled or one-off (suffixes such as `OLD` or `XXX`, dated copies of config): confirm nothing references them. Identical copies are left out of the ledger (SKILL.md, tree.sh).

A hook whose body is a commented-out call does nothing.
