#!jinja|yaml

{% set datamap = salt['formhelper.get_defaults']('mysql', saltenv) %}
{% set comp_type = datamap['type'] %}
{% set comp_data = datamap[comp_type]|default({}) %}
{% set pcs_data = datamap['pcs'] %}

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
        - 'check_passwd={{ comp_data.server.rootpwd|default('-enM1kEmC1S8D50ABKXdz5hlXQTAm2z5') }}'
        - 'check_user=root'
        - 'wsrep_cluster_address={{pcs_data.wsrep_cluster_address}}'
        - 'enable_creation=true'
        - 'datadir={{pcs_data.datadir|default(datamap.datadir)}}'
        - 'pid={{pcs_data.pid|default(datamap.pid)}}'
        - 'log={{pcs_data.log|default(datamap.log)}}'
        - 'socket={{pcs_data.socket|default(datamap.mysql_socket)}}'
        #- '--open-files-limit={{pcs_data.open_files_limit|default("16384")}}'
        - '--master'
        - 'meta'
        - 'master-max={{pcs_data.master_max}}'
        {% if pcs_data.get('ordered', False) %}
        - 'ordered=true'
        {% endif %}
        - 'op'
        - 'start'
        - 'interval=0s'
        - 'timeout={{pcs_data.op_start_timeout|default("120")}}'
        - 'op'
        - 'stop'
        - 'interval=0s'
        - 'timeout={{pcs_data.op_stop_timeout|default("120")}}'
        - 'op'
        - 'monitor'
        - 'interval={{pcs_data.op_monitor_interval|default("20")}}'
        - 'timeout={{pcs_data.op_monitor_timeout|default("30")}}'
        - 'op'
        - 'promote'
        - 'interval=0s'
        - 'timeout={{pcs_data.op_promote_timeout|default("300")}}'
        - 'op'
        - 'demote'
        - 'interval=0s'
        - 'timeout={{pcs_data.op_demote_timeout|default("120")}}'
        {% if pcs_data.get('on_fail', False) %}
        - 'on-fail={{pcs_data.on_fail|default("block")}}'
        {% endif %}

{% if pcs_data.galera_cib is defined and pcs_data.galera_cib %}
    - cibname: {{pcs_data.galera_cib}}
    - require:
      - pcs: mysql_pcs__cib_present_{{pcs_data.galera_cib}}
{% endif %}

{% if 'constraints' in pcs_data %}
{% for constraint, constraint_data in pcs_data.constraints.items()|sort %}
mysql_pcs__constraint_present_{{constraint}}:
  pcs.constraint_present:
    - constraint_id: {{constraint}}
    - constraint_type: "{{constraint_data.constraint_type}}"
    - constraint_options: {{constraint_data.constraint_options|json}}
{% if pcs_data.galera_cib is defined and pcs_data.galera_cib %}
    - require:
      - pcs: mysql_pcs__cib_present_{{pcs_data.galera_cib}}
    - require_in:
      - pcs: mysql_pcs__cib_pushed_{{pcs_data.galera_cib}}
    - cibname: {{pcs_data.galera_cib}}
{% endif %}
{% endfor %}
{% endif %}


{% if pcs_data.galera_cib is defined and pcs_data.galera_cib %}
mysql_pcs__cib_pushed_{{pcs_data.galera_cib}}:
  pcs.cib_pushed:
    - cibname: {{pcs_data.galera_cib}}
    - require:
      - pcs: mysql_pcs__resource_present_{{pcs_data.resource_name}}
{% endif %}

{% if salt['grains.get']('os_family') in ['RedHat', 'Suse', 'Debian' ] %}
mysql_pcs__set_root_access:
  cmd.wait:
    - name: |
        starttries=55
        tries=$starttries
        pcs_clear_pass=` expr $starttries - 5 ` 
        startupok=NOOK
        pcs resource cleanup {{pcs_data.resource_name}};
        while [ $tries -gt 1 ] ; do 
            tries=` expr $tries - 1` 
            if  ! mysql --user root --password='{{ comp_data.server.rootpwd|default('-enM1kEmC1S8D50ABKXdz5hlXQTAm2z5') }}' --execute="SELECT 1;"; then
               mysqladmin --user root password '{{ comp_data.server.rootpwd|default('-enM1kEmC1S8D50ABKXdz5hlXQTAm2z5') }}'
               mysqladmin --user root --password='' password '{{ comp_data.server.rootpwd|default('-enM1kEmC1S8D50ABKXdz5hlXQTAm2z5') }}'
               #mysql -u root -e "FLUSH PRIVILEGES;"
               #mysql -u root --password='' -e "FLUSH PRIVILEGES;"
               #mysql -u root -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('{{ comp_data.server.rootpwd|default('-enM1kEmC1S8D50ABKXdz5hlXQTAm2z5') }}');"
               #mysql -u root --password='' -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('{{ comp_data.server.rootpwd|default('-enM1kEmC1S8D50ABKXdz5hlXQTAm2z5') }}');"
               #mysql -u root -e "FLUSH PRIVILEGES;"
               #mysql -u root --password='' -e "FLUSH PRIVILEGES;"
            else
               startupok=OK
               break
            fi;
            sleep 5;
            if [ $tries -eq $pcs_clear_pass ] ; then 
                pcs resource update {{pcs_data.resource_name}} check_user='root' check_passwd= &&
                pcs resource cleanup {{pcs_data.resource_name}};
            fi
        done
        pcs resource update {{pcs_data.resource_name}} check_user='root' check_passwd='{{ comp_data.server.rootpwd|default('-enM1kEmC1S8D50ABKXdz5hlXQTAm2z5') }}' &&
        pcs resource cleanup {{pcs_data.resource_name}};
        break

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
