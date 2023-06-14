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
│   ├── backup
│   │   ├── do-backup
│   │   └── incremental-backup
│   └── systemd
│       ├── install-units
│       ├── mv-stg-backups
│       └── run-backup
└── util
    └── web
```

#### Inactive

Scripts under inactive are either in development, hopelessly malfunctioning w/ little to no hope of being fixed in the near-mid term, or just really no longer necessary/useful. 

#### System

Anything related to "system" mana

### Manifest

###

**TODO**

## To-Do List(s)

### New Tools

- [ ] run-backup system

### Tasks/Fixes

- [ ] Cleanup/deprecate scripts
- [ ] Write unit tests

## Fanciful Ideas

* **Deprecated** once I discovered [zoxide](https://github.com/ajeetdsouza/zoxide)
~~* fzf based `switch` utility that reads key to path mappings to search~~
~~* reads key to path mappings~~
~~* searches those paths based on the key provided at runtime~~
~~* search query (to find?) is parameterizable~~
~~* pipes output to fzf~~
~~* executes command on output~~
~~  * also potentially parameterizable~~
* util for automatically adding symbolic links~~
  * searches for hidden files, which contain link spec
  * creates links
* util for finding all dirs w/ a given property and dropping a file in
  them
  * intended to add .dropbox-ignore files in git repo dirs
  * thinking about it though, this could be accomplished w/ the first
    script I describe...

