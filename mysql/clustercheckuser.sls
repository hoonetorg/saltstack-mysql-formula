#!jinja|yaml

{% set datamap = salt['formhelper.get_defaults']('mysql', saltenv) %}
{% set comp_type = datamap['type'] %}
{% set comp_data = datamap[comp_type]|default({}) %}

#initialize a few dict's that are empty if no pillar or default setting overrides it
{% set clustercheck = comp_data['clustercheck']|default({}) %}
{% set user = clustercheck['user']|default({}) %}

{{ comp_type }}_clustercheck_user_{{ user.name|default('clustercheckuser') }}_{{ user.host|default('localhost') }}:
  mysql_user:
    - {{ user.ensure|default('present') }}
    - name: {{ user.name|default('clustercheckuser') }}
    - host: {{ user.host|default('localhost') }}
    - password: {{ user.password|default('clustercheckpassword!') }}
    - allow_passwordless: {{ user.passwordless|default(False) }}
    - unix_socket: {{ user.unix_socket|default(True) }}
    {# Salt MySQL conn config #}
  {% if datamap.salt.config.states|length > 0 %}
    - connection_host: {{ datamap.salt.config.states.host|default('localhost') }}
    - connection_user: {{ datamap.salt.config.states.user|default('root') }}
    - connection_pass: {{ datamap.salt.config.states.pass|default('enM1kEmC1S8D50ABKXdz5hlXQTAm2z5') }}
    - connection_charset: {{ datamap.salt.config.states.charset|default('utf8') }}
    - connection_unix_socket: {{ datamap.salt.config.states.socket|default(datamap.mysql_socket) }}
  {% elif 'default_file' in datamap.salt.config.states %}
    - connection_default_file: {{ datamap.salt.config.states.default_file }}
  {% endif %}

{{ comp_type }}_clustercheck_grant_{{ user.name|default('clustercheckuser') }}_{{ user.host|default('localhost') }}_{{ user.database|default('all') }}:
  mysql_grants:
    - {{ user.ensure|default('present') }}
    - user: {{ user.name|default('clustercheckuser') }}
    - host: {{ user.host|default('localhost') }}
    - database: '{{ user.database|default('*.*') }}'
    - grant: {{ user.grant|default(['process'])|join(',') }}
    - grant_option: {{ user.grant_option|default(False) }}
    - escape: {{ user.escape|default(True) }}
    - revoke_first: {{ user.revoke|default(False) }}
    {# Salt MySQL conn config #}
  {% if datamap.salt.config.states|length > 0 %}
    - connection_host: {{ datamap.salt.config.states.host|default('localhost') }}
    - connection_user: {{ datamap.salt.config.states.user|default('root') }}
    - connection_pass: {{ datamap.salt.config.states.pass|default('enM1kEmC1S8D50ABKXdz5hlXQTAm2z5') }}
    - connection_charset: {{ datamap.salt.config.states.charset|default('utf8') }}
    - connection_unix_socket: {{ datamap.salt.config.states.socket|default(datamap.mysql_socket) }}
  {% elif 'default_file' in datamap.salt.config.states %}
    - connection_default_file: {{ datamap.salt.config.states.default_file }}
  {% endif %}
