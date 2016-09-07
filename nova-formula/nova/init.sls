{% from "nova/map.jinja" import controller, openstack with context %}
{% set keystone_connection_args = "
    - connection_token: " + openstack.identity.admin_token + "
    - connection_endpoint: http://" + openstack.identity.host + ":35357/v2.0"
%}

nova_start_event:
  event.send:
    - name: formula_status
    - data:
        status: Installing nova

# Creating database and db users
nova_database:
  mysql_database.present:
    - name: {{ controller.database.name }}

nova_db_user:
  mysql_user.present:
    - name: {{ controller.database.user }}
    - host: {{ openstack.database.host }}
    - password: {{ controller.database.password }}
    - require:
      - mysql_database: nova_database
  mysql_grants.present:
    - grant: all privileges
    - database: "{{ controller.database.name }}.*"
    - user: {{ controller.database.user }}
    - host: {{ openstack.database.host }}
    - require:
      - mysql_user: nova_db_user

nova_db_user_percent:
  mysql_user.present:
    - name: {{ controller.database.user }}
    - host: "%"
    - password: {{ controller.database.password }}
    - require:
      - mysql_database: nova_database
  mysql_grants.present:
    - grant: all privileges
    - database: "{{ controller.database.name }}.*"
    - user: {{ controller.database.user }}
    - host: "%"
    - require:
      - mysql_user: nova_db_user_percent

# Creating keystone user, service and endpoints
nova_user:
  keystone.user_present:
    - name: {{ openstack.nova.user }}
    - password: {{ openstack.nova.password }}
    - tenant: service
    - email: root@localhost # TODO: get admin email
    - roles:
        service:
          - admin
    {{ keystone_connection_args }}

nova_keystone_service:
  keystone.service_present:
    - name: nova
    - service_type: compute
    - description: OpenStack Compute
    - require:
      - keystone: nova_user
    {{ keystone_connection_args }}

nova_endpoints:
  keystone.endpoint_present:
    - name: nova
    - publicurl: {{ controller.endpoints.get('public_protocol', 'http') }}://{{ openstack.identity.host }}:{{ controller.endpoints.public_port }}{{ controller.endpoints.get('public_path', '') }}
    - internalurl: {{ controller.endpoints.get('internal_protocol', 'http') }}://{{ openstack.identity.host }}:{{ controller.endpoints.internal_port }}{{ controller.endpoints.get('internal_path', '') }}
    - adminurl: {{ controller.endpoints.get('admin_protocol', 'http') }}://{{ openstack.identity.host }}:{{ controller.endpoints.admin_port }}{{ controller.endpoints.get('admin_path', '') }}
    - region: RegionOne
    - require:
      - keystone: nova_keystone_service
    {{ keystone_connection_args }}

# Installing packages
nova_pkgs:
  pkg.installed:
    - names: {{ controller.pkgs }}

# Managing config file
/etc/nova/nova.conf:
  file.managed:
    - source: salt://nova/files/nova.conf
    - template: jinja
    - require:
      - pkg: nova_pkgs

# Starting services
nova_services:
  service.running:
    - names: {{ controller.services }}
    - enable: True
    - require:
      - mysql_grants: nova_db_user
      - mysql_grants: nova_db_user_percent
      - keystone: nova_endpoints
    - watch:
      - file: /etc/nova/nova.conf

# Creating ssh key
nova_create_ssh_key:
  cmd.run:
    - name: ssh-keygen -q -N "" -f ~/.ssh/id_rsa
    - creates: /root/.ssh/id_rsa
    - requires:
      - service: nova_services

nova_add_ssh_key:
  cmd.run:
    - name: source /root/admin-openrc.sh && nova keypair-add --pub-key /root/.ssh/id_rsa.pub mykey
  - unless: source /root/admin-openrc.sh && openstack keypair list | grep mykey
    - require:
      - cmd: nova_create_ssh_key

nova_finished_event:
  event.send:
    - name: formula_status
    - data:
        status: Finished installing nova
    - require:
        - cmd: nova_add_ssh_key

nova_failed_event:
  event.send:
    - name: formula_status
    - data:
        status: Failed installing nova
    - onfail:
        - event: nova_finished_event
