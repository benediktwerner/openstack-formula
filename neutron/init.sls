{% from "neutron/map.jinja" import server with context %}

#Creating database and db users
neutron_database:
  mysql_database.present:
    - name: {{ server.database.name }}

neutron_db_user:
  mysql_user.present:
    - name: {{ server.database.user }}
    - host: {{ server.database.host }}
    - password: {{ server.database.password }}
    - require:
      - mysql_database: neutron_database
  mysql_grants.present:
    - grant: all privileges
    - database: "{{ server.database.name }}.*"
    - user: {{ server.database.user }}
    - host: {{ server.database.host }}
    - require:
      - mysql_user: neutron_db_user

neutron_db_user_percent:
  mysql_user.present:
    - name: {{ server.database.user }}
    - host: "%"
    - password: {{ server.database.password }}
    - require:
      - mysql_database: neutron_database
  mysql_grants.present:
    - grant: all privileges
    - database: "{{ server.database.name }}.*"
    - user: {{ server.database.user }}
    - host: "%"
    - require:
      - mysql_user: neutron_db_user_percent

# Installing packages
neutron_pkgs:
  pkg.installed:
    - names: {{ server.pkgs }}

neutron_pkgs_event:
  event.send:
    - name: formula_status
    - data:
        message: Installed neutron pkgs

# Managing config files
/etc/neutron/neutron.conf:
  file.managed:
    - source: salt://neutron/files/neutron.conf
    - template: jinja
    - require:
      - pkg: neutron_pkgs

/etc/neutron/plugins/ml2/ml2_conf.ini:
  file.managed:
    - source: salt://neutron/files/ml2_conf.ini
    - template: jinja
    - require:
      - pkg: neutron_pkgs

/etc/neutron/plugins/ml2/linuxbridge_agent.ini:
  file.managed:
    - source: salt://neutron/files/linuxbridge_agent.ini
    - template: jinja
    - require:
      - pkg: neutron_pkgs

/etc/neutron/dhcp_agent.ini:
  file.managed:
    - source: salt://neutron/files/dhcp_agent.ini
    - template: jinja
    - require:
      - pkg: neutron_pkgs

/etc/neutron/metadata_agent.ini:
  file.managed:
    - source: salt://neutron/files/metadata_agent.ini
    - template: jinja
    - require:
      - pkg: neutron_pkgs

neutron_services:
  service.running:
    - names: {{ server.services }}
    - enable: True
    - require:
      - mysql_grants: neutron_db_user
      - mysql_grants: neutron_db_user_percent
    - watch:
      - file: /etc/neutron/neutron.conf
      - file: /etc/neutron/plugins/ml2/ml2_conf.ini
      - file: /etc/neutron/plugins/ml2/linuxbridge_agent.ini
      - file: /etc/neutron/dhcp_agent.ini
      - file: /etc/neutron/metadata_agent.ini

neutron_event:
  event.send:
    - name: formula_status
    - data:
        message: Configured neutron
    - require:
      - service: neutron_services

neutron_create_net:
  cmd.run:
    - name: source /root/admin-openrc.sh && neutron net-create public --shared --provider:physical_network public --provider:network_type flat
    - unless: neutron net-list | grep public

neutron_create_subnet:
  cmd.run:
    - name: source /root/admin-openrc.sh && neutron subnet-create public {{ server.network.cidr }} --name public --allocation-pool start={{ server.network.allocation_start }},end={{ server.network.allocation_end }} --dns-nameserver {{ server.network.dns }} --gateway {{ server.network.gateway }}
    - unless: neutron subnet-list | grep {{ server.network.cidr }}


neutron_secgroup_icmp:
  cmd.run:
    - name: source /root/admin-openrc.sh && nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
    - unless: nova secgroup-list-rules default | grep icmp | grep 0.0.0.0/0

neutron_secgroup_ssh:
  cmd.run:
    - name: source /root/admin-openrc.sh && nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
    - unless: nova secgroup-list-rules default | grep tcp | grep 0.0.0.0/0 | grep 22
