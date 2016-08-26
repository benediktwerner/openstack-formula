{% from "neutron/map.jinja" import server, openstack with context %}
{% set keystone_connection_args = "
    - connection_token: " + openstack.identity.admin_token + "
    - connection_endpoint: http://" + openstack.identity.host + ":35357/v2.0"
%}

#Creating database and db users
neutron_database:
  mysql_database.present:
    - name: {{ server.database.name }}

neutron_db_user:
  mysql_user.present:
    - name: {{ server.database.user }}
    - host: {{ openstack.database.host }}
    - password: {{ server.database.password }}
    - require:
      - mysql_database: neutron_database
  mysql_grants.present:
    - grant: all privileges
    - database: "{{ server.database.name }}.*"
    - user: {{ server.database.user }}
    - host: {{ openstack.database.host }}
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

# Creating keystone user, service and endpoints
neutron_user:
  keystone.user_present:
    - name: {{ openstack.neutron.user }}
    - password: {{ openstack.neutron.password }}
    - tenant: service
    - email: root@localhost # TODO: get admin email
    - roles:
        service:
          - admin
    {{ keystone_connection_args }}

neutron_keystone_service:
  keystone.service_present:
    - name: neutron
    - service_type: network
    - description: OpenStack Networking
    - require:
      - keystone: neutron_user
    {{ keystone_connection_args }}

neutron_endpoints:
  keystone.endpoint_present:
    - name: neutron
    - publicurl: {{ server.endpoints.get('public_protocol', 'http') }}://{{ openstack.identity.host }}:{{ server.endpoints.public_port }}{{ server.endpoints.get('public_path', '') }}
    - internalurl: {{ server.endpoints.get('internal_protocol', 'http') }}://{{ openstack.identity.host }}:{{ server.endpoints.internal_port }}{{ server.endpoints.get('internal_path', '') }}
    - adminurl: {{ server.endpoints.get('admin_protocol', 'http') }}://{{ openstack.identity.host }}:{{ server.endpoints.admin_port }}{{ server.endpoints.get('admin_path', '') }}
    - region: RegionOne
    - require:
      - keystone: neutron_keystone_service
    {{ keystone_connection_args }}

# Installing packages
neutron_pkgs:
  pkg.installed:
    - names: {{ server.pkgs }}

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

# Starting services
neutron_services:
  service.running:
    - names: {{ server.services }}
    - enable: True
    - require:
      - mysql_grants: neutron_db_user
      - mysql_grants: neutron_db_user_percent
      - keystone: neutron_endpoints
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
        message: Installed neutron on {{ grains.id }}

{% if server.network.create_network %}
neutron_create_net:
  cmd.run:
    - name: source /root/admin-openrc.sh && neutron net-create public --shared --provider:physical_network public --provider:network_type flat
    - unless: source /root/admin-openrc.sh && neutron net-list | grep public

neutron_create_subnet:
  cmd.run:
    - name: source /root/admin-openrc.sh && neutron subnet-create public {{ server.network.cidr }} --name public --allocation-pool start={{ server.network.allocation_start }},end={{ server.network.allocation_end }} --dns-nameserver {{ server.network.dns }} --gateway {{ server.network.gateway }}
    - unless: source /root/admin-openrc.sh && neutron subnet-list | grep {{ server.network.cidr }}


neutron_secgroup_icmp:
  cmd.run:
    - name: source /root/admin-openrc.sh && nova secgroup-add-rule default icmp -1 -1 0.0.0.0/0
    - unless: source /root/admin-openrc.sh && nova secgroup-list-rules default | grep icmp | grep 0.0.0.0/0

neutron_secgroup_ssh:
  cmd.run:
    - name: source /root/admin-openrc.sh && nova secgroup-add-rule default tcp 22 22 0.0.0.0/0
    - unless: source /root/admin-openrc.sh && nova secgroup-list-rules default | grep tcp | grep 0.0.0.0/0 | grep 22

controller_finished_event:
  event.send:
    - name: formula_status
    - data:
        message: Finished installation on {{ grains.id }}
{% endif %}
