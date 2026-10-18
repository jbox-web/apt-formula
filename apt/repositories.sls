{% from "apt/map.jinja" import apt as apt_map with context %}
{% set apt = pillar.get('apt', {}) %}
{% set remove_sources_list = apt.get('remove_sources_list', apt_map.remove_sources_list) %}
{% set clean_sources_list_d = apt.get('clean_sources_list_d', apt_map.clean_sources_list_d) %}
{% set sources_list_dir = apt.get('sources_list_dir', apt_map.sources_list_dir) %}
{% set repositories = apt.get('repositories', apt_map.repositories) %}
{% set keyrings_dir = apt.get('keyrings_dir', apt_map.keyrings_dir) %}
{% set clean_keyrings_d = apt.get('clean_keyrings_d', apt_map.clean_keyrings_d) %}
{% set default_url = apt.get('default_url', apt_map.default_url) %}
{% set keyring_package = apt.get('keyring_package', apt_map.default_keyring_package) %}

{{ keyring_package }}:
  pkg.installed:
    - name: {{ keyring_package }}

/etc/apt/sources.list:
  file.managed:
    - mode: '0644'
    - user: root
    - group: root
  {% if remove_sources_list %}
    - contents: ''
    - contents_newline: False
  {% else %}
    - replace: False
  {% endif %}

{% set excluded_sources = [] %}
{% set unmanaged_repos = [] %}
{% for repo, args in repositories.items() %}
  {% if args.unmanaged is defined and args.unmanaged %}
    {# repo.list is considered the filename unless filename is explicitly defined.
     # managed repo lists files are constructed repo-type.list #}
    {% do excluded_sources.append(args.filename if args.filename is defined else repo ~ '.list') %}
    {% do unmanaged_repos.append(repo) %}
  {% endif %}
{% endfor %}
{% for repo in unmanaged_repos %}
  {# remove these repo's to avoid pgrepo.managed loop #}
  {% do repositories.pop(repo) %}
{% endfor %}

{{ sources_list_dir }}:
  file.directory:
    - mode: '0755'
    - user: root
    - group: root
    - clean: {{ clean_sources_list_d }}
    - exclude_pat: {{ excluded_sources | json }}

{{ keyrings_dir }}:
  file.directory:
    - mode: '0755'
    - user: root
    - group: root
    - clean: {{ clean_keyrings_d }}

{#- One deb822 file per repository: <repo>.sources. pkgrepo.managed is not used
    because Salt's aptpkg only reads and writes the one-line format. Keys are
    files named by `signed_by` (downloaded from `key_url` when set), so each
    key is trusted for its own repository only. keyid/keyserver and key_text
    are not supported. #}
{%- set old_trusted_keys = [] %}
{% for repo, args in repositories.items() %}
{%-   set types = [] %}
{%-   for type in args.type|d(['binary']) %}
{%-     do types.append('deb-src' if type == 'source' else 'deb') %}
{%-   endfor %}
{%-   set r_file = args.filename if args.filename is defined else repo ~ '.sources' %}
{%-   set signed_by = args.signed_by|d('') %}

{%-   if args.key_url is defined and signed_by %}
{%-     do old_trusted_keys.append('/etc/apt/trusted.gpg.d/' ~ signed_by.split('/')[-1]) %}

apt/repositories/key/{{ repo }}:
  file.managed:
    - name: {{ signed_by }}
    - source: {{ args.key_url }}
    {#- key_url has no published hash: same trust as the former pkgrepo download #}
    - skip_verify: True
    - user: root
    - group: root
    - mode: '0644'
    - makedirs: True
    - onchanges_in:
      - module: apt.refresh_db
{%-   endif %}

apt/repositories/source/{{ repo }}:
  file.managed:
    - name: {{ sources_list_dir }}/{{ r_file }}
    - user: root
    - group: root
    - mode: '0644'
    - contents: |
        Types: {{ types|join(' ') }}
        URIs: {{ args.url or default_url }}
        Suites: {{ args.distro or 'stable' }}
        Components: {{ args.comps|default(['main'])|join(' ') }}
        {%- if args.arch is defined %}
        Architectures: {{ args.arch|join(' ') }}
        {%- endif %}
        {%- if signed_by %}
        Signed-By: {{ signed_by }}
        {%- endif %}
    {%- if args.key_url is defined and signed_by %}
    - require:
      - file: apt/repositories/key/{{ repo }}
    {%- endif %}
    # require_in the directory clean state, so the file is kept, not removed
    # and added again.
    - require_in:
      - file: {{ sources_list_dir }}
    - onchanges_in:
      - module: apt.refresh_db
{% endfor %}

{#- Keys formerly downloaded into trusted.gpg.d were trusted for every
    repository: remove them, never a file a package ships. #}
{% for key in old_trusted_keys|unique %}
apt/repositories/old-key/{{ key }}:
  file.absent:
    - name: {{ key }}
    - unless: dpkg-query -S {{ key }}
    - onchanges_in:
      - module: apt.refresh_db
{% endfor %}

{% if repositories %}
apt.refresh_db:
  module.run:
    - name: pkg.refresh_db
{% endif %}
