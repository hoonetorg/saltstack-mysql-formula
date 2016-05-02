#!jinja|yaml

{% set datamap = salt['formhelper.get_defaults']('mysql', saltenv) %}
{% set comp_type = datamap['type'] %}
{% set comp_data = datamap[comp_type]|default({}) %}
{% set pcs_data = datamap['pcs'] %}

{% set resource_options = pcs_data['resource_options'] %}
{% if salt['grains.get']('os_family') in ['Debian' ] %}
{% set resource_options = resource_options + ['check_user=root', 'check_passwd=' + comp_data.server.rootpwd|default('-enM1kEmC1S8D50ABKXdz5hlXQTAm2z5')] %}
{% endif %}

# SLS includes/ excludes
include:
  - mysql._salt

{% if pcs_data.galera_cib is defined and pcs_data.galera_cib %}
mysql_pcs__cib_present_{{pcs_data.galera_cib}}:
  pcs.cib_present:
    - cibname: {{pcs_data.galera_cib}}
{% endif %}

mysql_pcs__resource_present_{{pcs_data.resource_name}}:
  pcs.resource_present:
    - resource_id: {{pcs_data.resource_name}}
    - resource_type: "{{pcs_data.resource_type|default('ocf:heartbeat:galera')}}"
    - resource_options:
        - 'wsrep_cluster_address={{pcs_data.wsrep_cluster_address}}'
        - 'enable_creation=true'
        - '--master'
        - 'meta'
        - 'master-max={{pcs_data.master_max}}'

{% if pcs_data.galera_cib is defined and pcs_data.galera_cib %}
    - cibname: {{pcs_data.galera_cib}}
    - require:
      - pcs: mysql_pcs__cib_present_{{pcs_data.galera_cib}}
{% endif %}

{% if pcs_data.galera_cib is defined and pcs_data.galera_cib %}
mysql_pcs__cib_pushed_{{pcs_data.galera_cib}}:
  pcs.cib_pushed:
    - cibname: {{pcs_data.galera_cib}}
    - require:
      - pcs: mysql_pcs__resource_present_{{pcs_data.resource_name}}
{% endif %}

{% if salt['grains.get']('os_family') in ['RedHat', 'Suse' ] %}
mysql_pcs__set_root_access:
  cmd.wait:
    - name: |
        while ! mysql --user root --password='{{ comp_data.server.rootpwd|default('-enM1kEmC1S8D50ABKXdz5hlXQTAm2z5') }}' --execute="SELECT 1;"; do
            mysqladmin --user root password '{{ comp_data.server.rootpwd|default('-enM1kEmC1S8D50ABKXdz5hlXQTAm2z5') }}' &&
            pcs resource update {{pcs_data.resource_name}} check_user='root' check_passwd='{{ comp_data.server.rootpwd|default('-enM1kEmC1S8D50ABKXdz5hlXQTAm2z5') }}' &&
            pcs resource cleanup {{pcs_data.resource_name}};
            sleep 5;
        done;
        pcs resource cleanup {{pcs_data.resource_name}};
    - timeout: 300
    - watch:
{% if pcs_data.galera_cib is defined and pcs_data.galera_cib %}
      - pcs: mysql_pcs__cib_pushed_{{pcs_data.galera_cib}}
{% else %}
      - pcs: mysql_pcs__resource_present_{{pcs_data.resource_name}}
{% endif %}

mysql_pcs__set_wait_cluster_resource_online:
  cmd.wait:
    - name: |
        for i in 1 2 3 4 5; do
          while ! mysql --user root --password='{{ comp_data.server.rootpwd|default('-enM1kEmC1S8D50ABKXdz5hlXQTAm2z5') }}' --execute="SELECT 1;"; do 
            sleep 5; 
          done;
          sleep 5;
        done
    - timeout: 300
    - watch:
      - cmd: mysql_pcs__set_root_access
{% endif %}
