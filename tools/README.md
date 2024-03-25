# Tools

This repo contains--or is intended to contain--production ready scripts that I regularly use in my day-to-day workflows. Lots of work is necessary before I get to that point.

## Contents

### Manifest

* log - user level logging utilities
* system - anything related to "system" management, i.e.: deployment, snapshotting (backups), cron, systemd, package management, etc.
* utils - miscellaneous utilities
* wip - scripts under inactive are either in development, hopelessly malfunctioning w/ little to no hope of being fixed in the near-mid term, or just really no longer necessary/useful

## To-Do List(s)

### Features/New Scripts

- [ ] Installation script
- [ ] Wrapper for xplr that gives callers the option to do something useful w/ the selected item (i.e.: cd into it, open it, edit it, delete it, etc.)
- [ ] Add more sophisticated TUI for snapshot
- [ ] Add standalone script script for restoration

### Tasks

- [ ] Write unit tests
- [ ] Migrate all tools/scripts to use ulogger
- [ ] Reorganize scripts

### Fixes

- [ ] Remove exec perms from run-snapshot and mv-stg-backups

### Done

- [x] Snapshot (backup) system for user files (ideally for arbitrary files)
- [x] (Nerd) Font installation: takes a font name as a param, checks if it's already installed, installs it if not
- [x] Fix 2-fa (issue caused by the fact that's it's dependent on an alias)

