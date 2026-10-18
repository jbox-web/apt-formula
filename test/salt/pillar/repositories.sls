# -*- coding: utf-8 -*-
# vim: ft=yaml
---
apt:
  remove_sources_list: true
  clean_sources_list_d: true

  repositories:
    unmanaged:
      unmanaged: true  # do not remove this file when clean_sources_list_d=true
      filename: unmanaged.list  # optional
    # Key shipped by a package, as for the Debian archive
    debian:
      distro: "{{ grains['oscodename'] }}"
      url: http://deb.debian.org/debian
      comps: [main]
      type: [binary]
      signed_by: /usr/share/keyrings/debian-archive-keyring.gpg
    # Key downloaded from `key_url` into its own keyring
    saltstack:
      distro: stable
      url: https://packages.broadcom.com/artifactory/saltproject-deb
      comps: [main]
      type: [binary]
      key_url: https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public  # yamllint disable-line rule:line-length
      signed_by: /etc/apt/keyrings/salt-archive-keyring.pgp
