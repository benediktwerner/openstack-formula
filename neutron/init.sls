{% from "openstack/neutron/map.jinja" import server with context %}

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


# Managing config files
/etc/neutron/neutron.conf:
  file.managed:
    - source: salt://openstack/neutron/files/neutron.conf
    - template: jinja
    - require:
      - pkg: neutron_pkgs

/etc/neutron/plugins/ml2/ml2_conf.ini:
  file.managed:
    - source: salt://openstack/neutron/files/ml2_conf.ini
    - template: jinja
    - require:
      - pkg: neutron_pkgs

/etc/neutron/plugins/ml2/linuxbridge_agent.ini:
  file.managed:
    - source: salt://openstack/neutron/files/linuxbridge_agent.ini
    - template: jinja
    - require:
      - pkg: neutron_pkgs

/etc/neutron/dhcp_agent.ini:
  file.managed:
    - source: salt://openstack/neutron/files/dhcp_agent.ini
    - template: jinja
    - require:
      - pkg: neutron_pkgs

/etc/neutron/metadata_agent.ini:
  file.managed:
    - source: salt://openstack/neutron/files/metadata_agent.ini
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
