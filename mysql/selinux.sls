#!jinja|yaml

{% set datamap = salt['formhelper.get_defaults']('mysql', saltenv) %}
{% set comp_type = datamap['type'] %}
{% set comp_data = datamap[comp_type]|default({}) %}

{% if comp_data.selinux_type is defined and comp_data.selinux_type %}
{{ comp_type }}_selinux_module_file:
  file.managed:
    - name: /etc/{{comp_data.selinux_type}}.pp
    - source: salt://mysql/files/{{comp_data.selinux_type}}.pp
    - user: root
    - group: root
    - mode: 0600

{{ comp_type }}_selinux_module_install:
  cmd.run:
    - name: semodule -i /etc/{{comp_data.selinux_type}}.pp
    - unless: semodule -l |grep -q '{{comp_data.selinux_type}}'
{% endif %}
