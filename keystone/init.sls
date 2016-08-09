{% from "openstack/keystone/map.jinja" import server with context %}
{% set keystone_connection_args = "
    - connection_token: " + server.service_token + "
    - connection_endpoint: http://" + server.host + ":35357/v2.0"
%}

#Creating database and db users
keystone_database:
  mysql_database.present:
    - name: {{ server.database.name }}

keystone_db_user:
  mysql_user.present:
    - name: {{ server.database.user }}
    - host: {{ server.database.host }}
    - password: {{ server.database.password }}
    - require:
      - mysql_database: keystone_database
  mysql_grants.present:
    - grant: all privileges
    - database: "{{ server.database.name }}.*"
    - user: {{ server.database.user }}
    - host: {{ server.database.host }}
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
    - source: salt://openstack/keystone/files/keystone.conf
    - template: jinja
    - require:
      - pkg: keystone_pkgs

/etc/sysconfig/apache2:
  file.managed:
    - source: salt://openstack/keystone/files/sysconfig-apache2
    - template: jinja
    - require:
      - pkg: keystone_pkgs

/etc/apache2/conf.d/wsgi-keystone.conf:
  file.managed:
    - source: salt://openstack/keystone/files/wsgi-keystone.conf
    - template: jinja
    - require:
      - pkg: keystone_pkgs

{# API v3 required (mikata)
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
    - source: salt://openstack/keystone/files/keystone.domain.conf
    - require:
      - file: /etc/keystone/domains
    - watch_in:
      - service: apache2

keystone_domain_{{ domain_name }}:
  cmd.run:
    - name: openstack domain create --description "{{ domain.description }}" {{ domain_name }} --os-token {{ server.service_token }} --os-url http://{{ server.host }}:35357/v2.0
    - unless: openstack domain list --os-token {{ server.service_token }} --os-url http://{{ server.host }}:35357/v2.0 | grep "{{ domain_name }}"
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

# Creating roles and service/admin tenants/users

keystone_service_tenant:
  keystone.tenant_present:
    - name: {{ server.service_tenant }}
    - description: "Service Project"
    - require:
      - cmd: keystone_syncdb
      - service: apache2
    {{ keystone_connection_args }}

keystone_admin_tenant:
  keystone.tenant_present:
    - name: {{ server.admin_tenant }}
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
    - tenant: {{ server.admin_tenant }}
    - roles:
      {{ server.admin_tenant }}:
        - admin
    - require:
      - keystone: keystone_admin_tenant
      - keystone: keystone_roles
    {{ keystone_connection_args }}

# Managing admin login script
/root/admin-openrc.sh:
  file.managed:
    - source: salt://openstack/keystone/files/admin-openrc.sh
    - template: jinja
    - require:
      - keystone: keystone_admin_user

# Creating services
{% for service_name, service in server.get('service', {}).iteritems() %}

keystone_{{ service_name }}_service:
  keystone.service_present:
    - name: {{ service_name }}
    - service_type: {{ service.type }}
    - description: {{ service.description }}
    - require:
      - keystone: keystone_roles
    {{ keystone_connection_args }}

keystone_{{ service_name }}_endpoint:
  keystone.endpoint_present:
    - name: {{ service_name }}
    - publicurl: '{{ service.bind.get('public_protocol', 'http') }}://{{ service.bind.get('public_address', server.host) }}:{{ service.bind.public_port }}{{ service.bind.get('public_path', 'v2.0') }}'
    - internalurl: '{{ service.bind.get('internal_protocol', 'http') }}://{{ service.bind.get('internal_address', server.host) }}:{{ service.bind.internal_port }}{{ service.bind.get('internal_path', 'v2.0') }}'
    - adminurl: '{{ service.bind.get('admin_protocol', 'http') }}://{{ service.bind.get('admin_address', server.host) }}:{{ service.bind.admin_port }}{{ service.bind.get('admin_path', 'v2.0') }}'
    - region: {{ service.get('region', 'RegionOne') }}
    - require:
      - keystone: keystone_{{ service_name }}_service
    {{ keystone_connection_args }}

{% if service.user is defined %}

keystone_user_{{ service.user.name }}:
  keystone.user_present:
    - name: {{ service.user.name }}
    - password: {{ service.user.password }}
    - email: {{ server.admin_email }}
    - tenant: {{ server.service_tenant }}
    - roles:
        {{ server.service_tenant }}:
          - admin
    - require:
      - keystone: keystone_roles
    {{ keystone_connection_args }}

{% endif %}
{% endfor %}

# Creating tenants
{% for tenant_name, tenant in server.get('tenant', {}).iteritems() %}

keystone_tenant_{{ tenant_name }}:
  keystone.tenant_present:
    - name: {{ tenant_name }}
    - require:
      - keystone: keystone_roles

{% for user_name, user in tenant.get('user', {}).iteritems() %}

keystone_user_{{ user_name }}:
  keystone.user_present:
    - name: {{ user_name }}
    - password: {{ user.password }}
    - email: {{ user.get('email', 'root@localhost') }}
    - tenant: {{ tenant_name }}
    - roles:
        {{ tenant_name }}:
          {%- if user.get('roles', False) %}
          {{ user.roles }}
          {%- else %}
          - user
          {%- endif %}
    - require:
      - keystone: keystone_tenant_{{ tenant_name }}

{% endfor %}
{% endfor %}
