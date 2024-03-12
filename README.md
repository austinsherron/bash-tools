# Tools

This repo contains--or is intended to contain--production ready scripts that I regularly use in my day-to-day workflows. Lots of work is necessary before I get to that point.

## Contents

### Structure

```
.
├── inactive
│   ├── deprecated
│   └── wip
├── system
│   ├── snapshot
│   └── systemd
│       ├── mv-stg-backups
│       └── run-snapshot
└── util
    └── web
```

* Git - Custom git scripts.
* Inactive - Scripts under inactive are either in development, hopelessly malfunctioning w/ little to no hope of being fixed in the near-mid term, or just really no longer necessary/useful. 
* System - Anything related to "system" management, i.e.: backups, systemd units, etc.
* Utils - Miscellaneous utilities.

## To-Do List(s)

### Features/New Scripts

- [x] Snapshot (backup) system for user files (ideally for arbitrary files)
- [ ] Formalize git functions by creating scripts for them/add scripts for oft-repeated git tasks
- [x] (Nerd) Font installation: takes a font name as a param, checks if it's already installed, installs it if not
- [ ] Wrapper for xplr that gives callers the option to do something useful w/ the selected item (i.e.: cd into it, open it, edit it, delete it, etc.)
- [ ] Add more sophisticated TUI for snapshot
- [ ] Add standalone script script for restoration

### Tasks

- [ ] Write unit tests
- [ ] Migrate all tools/scripts to use ulogger

### Fixes

- [x] Fix 2-fa (issue caused by the fact that's it's dependent on an alias)
- [ ] Remove exec perms from run-snapshot and mv-stg-backups

## Fanciful Ideas

* Util for automatically adding symbolic links
  * Searches for hidden files, which contain link spec
  * Creates links
* Util for finding all dirs w/ a given property and dropping a file in them
  * Intended to add .dropbox-ignore files in git repo dirs
  * Thinking about it though, this could be accomplished w/ the first script I
    describe...

