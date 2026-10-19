# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

The parent `../CLAUDE.md` describes the collection, the toolchain and the
`template-formula` layout. This file only records where `apt-formula` departs
from it.

## Commands

```bash
bundle install
bin/kitchen list                                  # 3 suites x 3 platforms = 9 instances
bin/kitchen test repositories-debian-13-3008-2    # one suite on one platform
pre-commit run --all-files
```

Suites: `repositories`, `preferences`, `unattended`. Each converges only the
states it tests (see `state_top` in `kitchen.yml`), never a whole `apt` tree.

## Not the template layout

- **No `apt/init.sls`.** Every state is standalone and must be targeted by name
  (`apt.repositories`, `apt.preferences`, `apt.unattended`, `apt.apt_conf`,
  `apt.listchanges`, `apt.update`, `apt.upgrade`, `apt.dist_upgrade`, `apt.ppa`,
  `apt.transports.*`). There are no `package/`, `config/`, `service/`
  subdirectories, no `libtofs.jinja`, and no `defaults.yaml` / `os*map.yaml`.
- **`map.jinja` is a single inline `grains.filter_by` on `os`** (Debian /
  Ubuntu, default Debian), merged with an `oscodename` table (Mint) and with
  pillar `apt:lookup`. The Debian defaults compute the components from
  `osmajorrelease` (`non-free-firmware` from Debian 12) and define three default
  repositories, used only when pillar sets no `apt:repositories`.
- **Pillar lookup is per key, not merged.** States read `pillar['apt']` and fall
  back key by key to the map (`apt.get('repositories', apt_map.repositories)`):
  a pillar `apt:repositories` *replaces* the default repositories wholesale.
  `apt.unattended`'s templates read `apt:unattended` directly from pillar, with
  their defaults hardcoded in `apt/templates/*.jinja`; `map.jinja` only supplies
  paths and the package list there.
- **`_mapdata` exists but has no reference dumps** under
  `test/integration/*/files/`: the controls assert on the managed files only.

## `apt.repositories`

The state no longer uses `pkgrepo.managed`: Salt's `aptpkg` only reads and
writes the one-line format. It writes one **deb822** file per repository,
`<sources_list_dir>/<repo>.sources` (or `filename`), with `Types` derived from
`type` (`source` → `deb-src`, anything else → `deb`).

- Keys: `signed_by` names the keyring file; with `key_url` it is downloaded
  there (`skip_verify: True`, no published hash). `key_url` without
  `signed_by` downloads nothing. `keyid` / `keyserver` / `key_text` are not
  supported, and `opts` is ignored: a `signed-by=` written in `opts` produces
  no `Signed-By:` line.
- A key downloaded this way that also sits in `/etc/apt/trusted.gpg.d/` under
  the same basename is removed, unless a package owns it (`dpkg-query -S`).
- `unmanaged: true` repositories are excluded from `clean_sources_list_d` and
  dropped from the loop; their file is created elsewhere (in tests,
  `test/salt/states/unmanaged.sls`).
- Every managed file is `require_in` its directory, so `clean: True` on
  `sources_list_dir` / `keyrings_dir` keeps it instead of removing and
  re-adding it. Any new file state there needs the same `require_in`.
- `apt.refresh_db` (a `module.run` of `pkg.refresh_db`) exists only when at
  least one repository is managed, and is triggered by `onchanges_in`.

`apt.update`, `apt.upgrade` and `apt.dist_upgrade` run `apt-get` on changes to
`/etc/apt/sources.list` or `/etc/apt/sources.list.d`, so they only work in the
same run as `apt.repositories`.

## Tests

- The `repositories` suite runs `states/unmanaged` before `apt.repositories`
  and asserts that `clean_sources_list_d` removes the `salt.sources` file the
  Salt image ships. The Debian 11 platform rewrites `/etc/apt/sources.list` in
  `provision_command`, but the suite empties that file
  (`remove_sources_list: true`).
- `preferences` and `unattended` feed their pillar through
  `pillars_from_files` as `apt.sls`, not through `pillars_from_directories`.

## Docs

`docs/README.rst` lists the states; `pillar.example` is the reference for
pillar keys. The README still describes some upstream behaviour (its testing
section names `debian-9-2019-2-py3`): trust the `.sls` files when they
disagree.
