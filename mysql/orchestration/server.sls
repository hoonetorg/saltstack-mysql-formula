#!jinja|yaml
#formhelper not working with salt-run
{# set datamap = salt['formhelper.get_defaults']('mysql', saltenv) %}
{% set pcs_data = datamap['pcs'] %}

{% set node_ids = pcs_data.node_ids -%}
{% set admin_node_id = pcs_data.admin_node_id -#}

{% set node_ids = salt['pillar.get']('mysql:lookup:pcs:node_ids') -%}
{% set admin_node_id = salt['pillar.get']('mysql:lookup:pcs:admin_node_id') -%}

# node_ids: {{node_ids|json}}
# admin_node_id: {{admin_node_id}}

mysql_orchestration_server__node_ids_server:
  salt.state:
    - tgt: {{node_ids|json}}
    - tgt_type: list
    - expect_minions: True
    - sls: mysql.server

mysql_orchestration_server__pcs:
  salt.state:
    - tgt: {{admin_node_id}}
    - expect_minions: True
    - sls: mysql.pcs
    - require:
      - salt: mysql_orchestration_server__node_ids_server

mysql_orchestration_server__dbmgmt:
  salt.state:
    - tgt: {{admin_node_id}}
    - expect_minions: True
    - sls: mysql._dbmgmt
    - require:
      - salt: mysql_orchestration_server__pcs

mysql_orchestration_server__clustercheckuser:
  salt.state:
    - tgt: {{admin_node_id}}
    - expect_minions: True
    - sls: mysql.clustercheckuser
    - require:
      - salt: mysql_orchestration_server__dbmgmt

mysql_orchestration_server__clustercheck:
  salt.state:
    - tgt: {{node_ids|json}}
    - tgt_type: list
    - expect_minions: True
    - sls: mysql.clustercheck
    - require:
      - salt: mysql_orchestration_server__clustercheckuser

