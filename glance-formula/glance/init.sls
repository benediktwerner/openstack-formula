{% from "glance/map.jinja" import server, openstack with context %}
{% set keystone_connection_args = "
    - connection_token: " + openstack.identity.admin_token + "
    - connection_endpoint: http://" + openstack.identity.host + ":35357/v2.0"
%}

glance_start_event:
  event.send:
    - name: formula_status
    - data:
        status: Installing glance

# Creating database and db users
glance_database:
  mysql_database.present:
    - name: {{ server.database.name }}

glance_db_user:
  mysql_user.present:
    - name: {{ server.database.user }}
    - host: {{ openstack.database.host }}
    - password: {{ server.database.password }}
    - require:
      - mysql_database: glance_database
  mysql_grants.present:
    - grant: all privileges
    - database: "{{ server.database.name }}.*"
    - user: {{ server.database.user }}
    - host: {{ openstack.database.host }}
    - require:
      - mysql_user: glance_db_user

glance_db_user_percent:
  mysql_user.present:
    - name: {{ server.database.user }}
    - host: "%"
    - password: {{ server.database.password }}
    - require:
      - mysql_database: glance_database
  mysql_grants.present:
    - grant: all privileges
    - database: "{{ server.database.name }}.*"
    - user: {{ server.database.user }}
    - host: "%"
    - require:
      - mysql_user: glance_db_user_percent

# Creating keystone user, service and endpoints
glance_user:
  keystone.user_present:
    - name: {{ openstack.glance.user }}
    - password: {{ openstack.glance.password }}
    - tenant: service
    - email: root@localhost # TODO: get admin email
    - roles:
        service:
          - admin
    {{ keystone_connection_args }}

glance_keystone_service:
  keystone.service_present:
    - name: glance
    - service_type: image
    - description: OpenStack Image service
    - require:
      - keystone: glance_user
    {{ keystone_connection_args }}

glance_endpoints:
  keystone.endpoint_present:
    - name: glance
    - publicurl: {{ server.endpoints.get('public_protocol', 'http') }}://{{ openstack.identity.host }}:{{ server.endpoints.public_port }}{{ server.endpoints.get('public_path', '') }}
    - internalurl: {{ server.endpoints.get('internal_protocol', 'http') }}://{{ openstack.identity.host }}:{{ server.endpoints.internal_port }}{{ server.endpoints.get('internal_path', '') }}
    - adminurl: {{ server.endpoints.get('admin_protocol', 'http') }}://{{ openstack.identity.host }}:{{ server.endpoints.admin_port }}{{ server.endpoints.get('admin_path', '') }}
    - region: RegionOne
    - require:
      - keystone: glance_keystone_service
    {{ keystone_connection_args }}

# Installing glance packages
glance_packages:
  pkg.installed:
    - names: {{ server.pkgs }}

# Managing config files
/etc/glance/glance-api.conf:
  file.managed:
    - source: salt://glance/files/glance-api.conf
    - template: jinja
    - require:
      - pkg: glance_packages

/etc/glance/glance-registry.conf:
  file.managed:
    - source: salt://glance/files/glance-registry.conf
    - template: jinja
    - require:
      - pkg: glance_packages

# Starting glance services
glance_services:
  service.running:
    - names: {{ server.services }}
    - enable: True
    - require:
      - mysql_grants: glance_db_user
      - mysql_grants: glance_db_user_percent
      - keystone: glance_endpoints
    - watch:
      - file: /etc/glance/glance-api.conf
      - file: /etc/glance/glance-registry.conf

{% if server.image.upload_image %}
glance_uploading_event:
  event.send:
    - name: formula_status
    - data:
        message: 'Uploading image: {{ server.image.name }}'
    - require:
      - service: glance_services

glance_download_image:
  cmd.run:
    - name: curl -L {{ server.image.url }} -o /tmp/{{server.image.name }}
    - creates: /tmp/{{ server.image.name }}
    - unless: source /root/admin-openrc.sh && openstack image list | grep {{ server.image.name }}
    - require:
      - service: glance_services

glance_upload_image:
  cmd.run:
    - name: source /root/admin-openrc.sh && glance image-create --name {{ server.image.name }} --file /tmp/{{server.image.name}} --disk-format {{server.image.disk_format}} --container-format {{server.image.container_format}} --visibility {{server.image.visibility}}
    - unless: source /root/admin-openrc.sh && openstack image list | grep {{ server.image.name }}
    - require:
      - cmd: glance_download_image
    - require_in:
        - event: glance_finished_event
{% endif %}

glance_finished_event:
  event.send:
    - name: formula_status
    - data:
        message: Finished installing glance
    - require:
      - service: glance_services

glance_failed_event:
  event.send:
    - name: formula_status
    - data:
        message: Failed installing glance
    - onfail:
      - event: glance_finished_event
