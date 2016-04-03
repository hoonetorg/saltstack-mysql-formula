#!jinja|yaml
#formhelper not working with salt-run
{# set datamap = salt['formhelper.get_defaults']('mysql', saltenv) %}
{% set pcs_data = datamap['pcs'] %}

{% set nodes = pcs_data.nodes -%}
{% set managementnode = pcs_data.managementnode -#}

{% set nodes = salt['pillar.get']('mysql:lookup:pcs:nodes') -%}
{% set managementnode = salt['pillar.get']('mysql:lookup:pcs:managementnode') -%}

# nodes: {{nodes|json}}
# managementnode: {{managementnode}}

mysql_orchestration_server__nodes_server:
  salt.state:
    - tgt: {{nodes|json}}
    - tgt_type: list
    - expect_minions: True
    - sls: mysql.server

mysql_orchestration_server__pcs:
  salt.state:
    - tgt: {{managementnode}}
    - expect_minions: True
    - sls: mysql.pcs
    - require:
      - salt: mysql_orchestration_server__nodes_server

mysql_orchestration_server__dbmgmt:
  salt.state:
    - tgt: {{managementnode}}
    - expect_minions: True
    - sls: mysql._dbmgmt
    - require:
      - salt: mysql_orchestration_server__pcs

mysql_orchestration_server__clustercheckuser:
  salt.state:
    - tgt: {{managementnode}}
    - expect_minions: True
    - sls: mysql.clustercheckuser
    - require:
      - salt: mysql_orchestration_server__dbmgmt

mysql_orchestration_server__clustercheck:
  salt.state:
    - tgt: {{nodes|json}}
    - tgt_type: list
    - expect_minions: True
    - sls: mysql.clustercheck
    - require:
      - salt: mysql_orchestration_server__clustercheckuser

