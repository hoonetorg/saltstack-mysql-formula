#!jinja|yaml

{% set datamap = salt['formhelper.get_defaults']('mysql', saltenv) %}
{% set comp_type = datamap['type'] %}
{% set comp_data = datamap[comp_type]|default({}) %}

{% set mysql_service = comp_data.server.service|default( {} ) %}
{% set mysql_service_ensure = mysql_service.ensure|default('running') %}

# SLS includes/ excludes
include: {{ comp_data.server.sls_include|default(['mysql._dbmgmt']) }}
extend: {{ comp_data.server.sls_extend|default({}) }}


{% for config in comp_data.server.config.manage %}
  {% set f = comp_data['server']['config'][config] %}

{{ comp_type }}_config_{{ config }}:
  file:
    - managed
    - name: {{ f.path|default('/etc/mysql/my.cnf') }}
    - source: {{ f.template_path|default('salt://mysql/files/my.cnf') }}
    - makedirs: {{ f.makedirs|default(True) }}
    - template: {{ f.template_renderer|default('jinja') }}
    - mode: {{ f.mode|default(640) }}
    - user: {{ f.user|default('root') }}
    - group: {{ f.group|default('root') }}
    - context:
      config: {{ f.config|default({})|json }}
    - require_in:
      - pkg: {{ comp_type }}_server
    {% if mysql_service_ensure != "disabled" %}
    - watch_in:
      - service: {{ comp_type }}_server
    {% endif %}
{% endfor %}


{% if salt['grains.get']('os_family') in ['Debian'] %}
{{ comp_type }}_debconf:
  debconf:
    - set
    - name: {{ comp_type }}-server
    - data:
        'mysql-server/root_password': {'type': 'password', 'value': '{{ comp_data.server.rootpwd|default('-enM1kEmC1S8D50ABKXdz5hlXQTAm2z5') }}'}
        'mysql-server/root_password_again': {'type': 'password', 'value': '{{ comp_data.server.rootpwd|default('-enM1kEmC1S8D50ABKXdz5hlXQTAm2z5') }}'}
        'mysql-server/start_on_boot': {'type': 'boolean', 'value': 'true'}
    - require_in:
      - pkg: {{ comp_type }}_server
{% endif %}


{{ comp_type }}_server:
  pkg:
    - installed
    - pkgs: {{ comp_data.server.pkgs }}
  service:
    - {{ mysql_service_ensure|default('running') }}
    - name: {{ comp_data.server.service.name }}
    {% if mysql_service_ensure != "disabled" %}
    - enable: {{ comp_data.server.service.enable|default(True) }}
    {% endif %}
    - require:
      - pkg: {{ comp_type }}_server
  cmd:
    - wait
    - name: sleep 5 && echo The daemon came back, going back to work.. {#- TODO: replace through service 'init_delay' param (not releasd yet) #}
    - watch:
      - service: {{ comp_type }}_server


# preparation done by galera agent option  'enable_creation=true'
{# if salt['grains.get']('os_family') in ['RedHat'] %}
{{ comp_type }}_init_create_db_files:
  cmd.run:
    - name: /usr/libexec/mariadb-prepare-db-dir {{ comp_data.server.service.name }}
    - user: root
    - group: root
    - unless: test -d /var/lib/mysql/mysql
{% endif #}
