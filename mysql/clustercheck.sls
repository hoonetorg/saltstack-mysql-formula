#!jinja|yaml


{% set datamap = salt['formhelper.get_defaults']('mysql', saltenv) %}
{% set comp_type = datamap['type'] %}
{% set comp_data = datamap[comp_type]|default({}) %}

#initialize a few dict's that are empty if no pillar or default setting overrides it
{% set clustercheck = comp_data['clustercheck']|default({}) %}
{% set user = clustercheck['user']|default({}) %}
{% set defaultsfile = clustercheck['defaultsfile']|default({}) %}
{% set service = clustercheck['service']|default({}) %}
{% set socket = clustercheck['socket']|default({}) %}
{% set rsyslog = clustercheck['rsyslog']|default({}) %}

{{ comp_type }}_clustercheck_defaults_file:
  file:
    - managed
    - name: {{ defaultsfile.path|default('/etc/sysconfig/clustercheck') }}
    - mode: {{ defaultsfile.mode|default(640) }}
    - user: {{ defaultsfile.user|default('root') }}
    - group: {{ defaultsfile.group|default('nobody') }}
    - contents: |
        MYSQL_USERNAME="{{ user.name|default('clustercheckuser') }}"
        MYSQL_PASSWORD="{{ user.password|default('clustercheckpassword!')}}"
        MYSQL_HOST="{{ user.host|default('localhost') }}"
        MYSQL_PORT="{{ user.port|default('3306') }}"
        ERR_FILE="{{ user.errfile|default('/dev/null') }}"
        AVAILABLE_WHEN_DONOR={{ user.av_when_donor|default('0') }}
        AVAILABLE_WHEN_READONLY={{ user.av_when_readonly|default('1') }}
        DEFAULTS_EXTRA_FILE="{{ user.defaults_extra_file|default('/etc/my.cnf') }}"

{% if grains['init'] in [ 'systemd' ] %}

{% if socket.path is defined and socket.path != '' %}
   {% do socket.update( {'servicename': socket['path'].split('/')|last} ) %}
{% endif %}

{{ comp_type }}_clustercheck_systemd_servicefile:
  file:
    - managed
    - name: {{ service.path|default('/etc/systemd/system/clustercheck@.service') }}
    - mode: {{ service.mode|default(644) }}
    - user: {{ service.user|default('root') }}
    - group: {{ service.group|default('root') }}
    - contents: |
        [Unit]
        Description=MySQL Clustercheck
        After=network.target
         
        [Service]
        User=nobody
        ExecStart=-/usr/bin/clustercheck "{{ user.name|default('clustercheckuser') }}" "{{ user.password|default('clustercheckpassword!')}}"
        StandardInput=socket

{{ comp_type }}_clustercheck_systemd_socketfile:
  file:
    - managed
    - name: {{ socket.path|default('/etc/systemd/system/clustercheck.socket') }}
    - mode: {{ socket.mode|default(640) }}
    - user: {{ socket.user|default('root') }}
    - group: {{ socket.group|default('root') }}
    - contents: |
        [Unit]
        Description=MySQL Clustercheck Socket
         
        [Socket]
        ListenStream=9200
        Accept=true
         
        [Install]
        WantedBy=sockets.target

#reload systemd daemon if service or socket units change
{{ comp_type }}_clustercheck_systemd_daemon_reload:
  module:
    - wait
    - name: service.systemctl_reload
    - watch:
      - file: {{ comp_type }}_clustercheck_systemd_servicefile
      - file: {{ comp_type }}_clustercheck_systemd_socketfile


{{ comp_type }}_clustercheck_systemd_socket:
  service:
    - {{socket.servicestate|default('running')}}
    - name: {{socket.servicename|default('clustercheck.socket')}}
    - enable: {{socket.enable|default('True')}}
    - watch:
      - module: {{ comp_type }}_clustercheck_systemd_daemon_reload


  {% if rsyslog.manage|default('True') %}
{{ comp_type }}_clustercheck_rsyslog:
  file:
    - managed
    - name: {{ rsyslog.path|default('/etc/rsyslog.d/mysql_clustercheck.conf') }}
    - mode: {{ rsyslog.mode|default(640) }}
    - user: {{ rsyslog.user|default('root') }}
    - group: {{ rsyslog.group|default('root') }}
    - contents: |
        # This file is managed by SaltStack - do not modify
        #
        # systemd log fixup - No, we don't want to log mysql clustercheck systemd
        # messages everytime haproxy connects (this is probably very often and spams logfiles)
        if $programname == 'systemd' and $msg contains 'Starting MySQL Clustercheck' then stop
        if $programname == 'systemd' and $msg contains 'Started MySQL Clustercheck' then stop
  module:
    - wait
    - name: service.restart
    # correct for osfamily RedHat(7) and Debian(Jessie) with systemd
    # fixme: os dependent rsyslog.servicename into defaults.yaml
    - m_name: {{rsyslog.servicename|default('rsyslog.service')}}
    - watch:
      - file: {{ comp_type }}_clustercheck_rsyslog
  {% endif %}

{% endif %}

