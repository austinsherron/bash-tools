# Tools

This repo contains--or is intended to contain--production ready scripts that I regularly use in my day-to-day workflows. Lots of work is necessary before I get to that point.

## To-Do List(s)

### Features/New Scripts

- [x] Installation script
- [x] Wrapper for xplr that gives callers the option to do something useful w/ the selected item (i.e.: cd into it, open it, edit it, delete it, etc.)
    - Needed to be a function: added in dotfiles
- [ ] `snapshot`
    - [ ] Add more sophisticated TUI
    - [ ] Add standalone script script for restoration
- [ ] Add cron to track wifi stats

### Tasks

- [ ] Write unit tests
- [ ] Migrate all tools/scripts to use ulogger
- [x] Reorganize scripts

### Fixes

- [ ] Remove exec perms from run-snapshot and mv-stg-backups

### Done

- [x] Snapshot (backup) system for user files (ideally for arbitrary files)
- [x] (Nerd) Font installation: takes a font name as a param, checks if it's already installed, installs it if not
- [x] Fix 2-fa (issue caused by the fact that's it's dependent on an alias)

