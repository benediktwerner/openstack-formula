{% from "keystone/map.jinja" import server, openstack with context %}
{% set keystone_connection_args = "
    - connection_token: " + openstack.identity.admin_token + "
    - connection_endpoint: http://" + openstack.identity.host + ":35357/v2.0"
%}

{# Code for setting up PostgresqlDB instead of MariaDB (not working with db_host)
#Creating database and db users
keystone_database:
  postgres_database.present:
    - name: {{ server.database.name }}

keystone_db_user:
  postgres_user.present:
    - name: {{ server.database.user }}
    - db_host: {{ openstack.database.host }}
    - db_password: {{ server.database.password }}
    - require:
      - postgres_database: keystone_database
  postgres_privileges.present:
    - name: {{ server.database.user }}
    - privileges: ALL
    - object_name: {{ server.database.name }}
    - object_type: database
    - db_host: {{ openstack.database.host }}
    - require:
      - postgres_user: keystone_db_user

keystone_db_user_percent:
  postgres_user.present:
    - name: {{ server.database.user }}
    - db_host: "%"
    - db_password: {{ server.database.password }}
    - require:
      - postgres_database: keystone_database
  postgres_privileges.present:
    - name: {{ server.database.user }}
    - privileges: ALL
    - object_name: {{ server.database.name }}
    - object_type: database
    - db_host: "%"
    - require:
      - postgres_user: keystone_db_user_percent
#}

#Creating database and db users
keystone_database:
  mysql_database.present:
    - name: {{ server.database.name }}

keystone_db_user:
  mysql_user.present:
    - name: {{ server.database.user }}
    - host: {{ openstack.database.host }}
    - password: {{ server.database.password }}
    - require:
      - mysql_database: keystone_database
  mysql_grants.present:
    - grant: all privileges
    - database: "{{ server.database.name }}.*"
    - user: {{ server.database.user }}
    - host: {{ openstack.database.host }}
    - require:
      - mysql_user: keystone_db_user

keystone_db_user_percent:
  mysql_user.present:
    - name: {{ server.database.user }}
    - host: "%"
    - password: {{ server.database.password }}
    - require:
      - mysql_database: keystone_database
  mysql_grants.present:
    - grant: all privileges
    - database: "{{ server.database.name }}.*"
    - user: {{ server.database.user }}
    - host: "%"
    - require:
      - mysql_user: keystone_db_user_percent

# Installing packages
keystone_pkgs:
  pkg.installed:
    - names: {{ server.pkgs }}

# Starting memcached service
memcached:
  service.running:
    - enable: True
    - require:
      - mysql_database: keystone_database
      - pkg: keystone_pkgs

# Managing config files
/etc/keystone/keystone.conf:
  file.managed:
    - source: salt://keystone/files/keystone.conf
    - template: jinja
    - require:
      - pkg: keystone_pkgs

/etc/sysconfig/apache2:
  file.managed:
    - source: salt://keystone/files/sysconfig-apache2
    - template: jinja
    - require:
      - pkg: keystone_pkgs

/etc/apache2/conf.d/wsgi-keystone.conf:
  file.managed:
    - source: salt://keystone/files/wsgi-keystone.conf
    - template: jinja
    - require:
      - pkg: keystone_pkgs

{# Currently not implemented
# Creating domains
{%- if server.get("domain", {}) %}

/etc/keystone/domains:
  file.directory:
    - mode: 0755
    - require:
      - pkg: keystone_pkgs

{%- for domain_name, domain in server.domain.iteritems() %}

/etc/keystone/domains/keystone.{{ domain_name }}.conf:
  file.managed:
    - source: salt://keystone/files/keystone.domain.conf
    - require:
      - file: /etc/keystone/domains
    - watch_in:
      - service: apache2

keystone_domain_{{ domain_name }}:
  cmd.run:
    - name: openstack domain create --description "{{ domain.description }}" {{ domain_name }} --os-token {{ server.admin_token }} --os-url http://{{ server.host }}:35357/v2.0
    - unless: openstack domain list --os-token {{ server.admin_token }} --os-url http://{{ server.host }}:35357/v2.0 | grep "{{ domain_name }}"
    - require:
      - service: apache2

{% endfor %}
{% endif %}
#}

# Managing config file ownership and syncing database
keystone_ownership:
  cmd.run:
    - name: "chown -R keystone:keystone /etc/keystone"
    - require:
      - pkg: keystone_pkgs

keystone_syncdb:
  cmd.run:
    - name: keystone-manage db_sync; sleep 1
    - require:
      - service: memcached

# Enabling apache2 version mod and starting apache service
a2enmod_version:
  cmd.run:
    - name: a2enmod version
    - unless: a2enmod -l | grep "version"
    - require:
      - pkg: keystone_pkgs

apache2:
  service.running:
    - enable: True
    - watch:
      - cmd: a2enmod_version
      - file: /etc/keystone/keystone.conf
      - file: /etc/sysconfig/apache2
      - file: /etc/apache2/conf.d/wsgi-keystone.conf

# Creating service and endpoints
keystone_service:
  keystone.service_present:
    - name: keystone
    - service_type: identity
    - description: OpenStack Identity
    - require:
      - service: apache2
    {{ keystone_connection_args }}

keystone_endpoints:
  keystone.endpoint_present:
    - name: keystone
    - publicurl: {{ server.endpoints.get('public_protocol', 'http') }}://{{ server.endpoints.get('public_address', server.host) }}:{{ server.endpoints.public_port }}{{ server.endpoints.get('public_path', '') }}
    - internalurl: {{ server.endpoints.get('internal_protocol', 'http') }}://{{ server.endpoints.get('internal_address', server.host) }}:{{ server.endpoints.internal_port }}{{ server.endpoints.get('internal_path', '') }}
    - adminurl: {{ server.endpoints.get('admin_protocol', 'http') }}://{{ server.endpoints.get('admin_address', server.host) }}:{{ server.endpoints.admin_port }}{{ server.endpoints.get('admin_path', '') }}
    - region: RegionOne
    - require:
      - keystone: keystone_service
    {{ keystone_connection_args }}

# Creating roles and service/admin tenants/users

keystone_service_tenant:
  keystone.tenant_present:
    - name: service
    - description: "Service Project"
    - require:
      - keystone: keystone_endpoints
    {{ keystone_connection_args }}

keystone_admin_tenant:
  keystone.tenant_present:
    - name: admin
    - description: "Admin Project"
    - require:
      - keystone: keystone_service_tenant
    {{ keystone_connection_args }}

keystone_roles:
  keystone.role_present:
    - names: {{ server.roles }}
    - require:
      - keystone: keystone_service_tenant
    {{ keystone_connection_args }}

keystone_admin_user:
  keystone.user_present:
    - name: {{ server.admin_name }}
    - password: {{ server.admin_password }}
    - email: {{ server.admin_email }}
    - tenant: admin
    - roles:
        admin:
          - admin
    - require:
      - keystone: keystone_admin_tenant
      - keystone: keystone_roles
    {{ keystone_connection_args }}

# Managing admin login script
/root/admin-openrc.sh:
  file.managed:
    - source: salt://keystone/files/admin-openrc.sh
    - template: jinja
    - require:
      - keystone: keystone_admin_user

keystone_event:
  event.send:
    - name: formula_status
    - data:
        message: Installed keystone on {{ grains.id }}
    - require:
      - file: /root/admin-openrc.sh
