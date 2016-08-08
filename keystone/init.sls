{% set keystone_db_pwd = "password" %}
{% set server = {
    'roles': ['admin', 'user']
  }
%}
{% set hostname = "controller.de.mo" %}
{# set connectiondetails = {
    'token': 'token',
    'endpoint': 'http://<hostname>:35357/v2.0'
  }
#}

keystone_database:
  mysql_database.present:
    - name: keystone

keystone_db_user_localhost:
  mysql_user.present:
    - name: keystone
    - host: localhost
    - password: {{ keystone_db_pwd }}
  mysql_grants.present:
    - grant: all privileges
    - database: "keystone.*"
    - user: keystone
    - host: localhost

keystone_db_user_percent:
  mysql_user.present:
    - name: keystone
    - host: "%"
    - password: {{ keystone_db_pwd }}
  mysql_grants.present:
    - grant: all privileges
    - database: "keystone.*"
    - user: keystone
    - host: "%"

keystone_pkgs:
  pkg.installed:
    - pkgs:
      - openstack-keystone
      - apache2-mod_wsgi
      - memcached
      - python-python-memcached

keystone_service:
  service.running:
    - name: memcached
    - enable: True

/etc/keystone/keystone.conf:
  file.managed:
    - source: salt://openstack/keystone/files/keystone.conf
    - template: jinja
    - require:
      - pkg: keystone_pkgs

keystone_syncdb:
  cmd.run:
  - name: keystone-manage db_sync; sleep 1
  - require:
    - service: keystone_service

/etc/sysconfig/apache2:
  file.managed:
    - source: salt://openstack/keystone/files/sysconfig-apache2
    - template: jinja

/etc/apache2/conf.d/wsgi-keystone.conf:
  file.managed:
    - source: salt://openstack/keystone/files/wsgi-keystone.conf
    - template: jinja

keystone_ownership:
  cmd.run:
    - name: "chown -R keystone:keystone /etc/keystone"

apache2:
  cmd.run:
    - name: "a2enmod version"
  service.running:
    - enable: True
    - watch:
      - cmd: apache2
      - file: /etc/sysconfig/apache2
      - file: /etc/apache2/conf.d/wsgi-keystone.conf

keystone_keystone_service:
  keystone.service_present:
    - name: keystone
    - service_type: identity
    - description: "OpenStack identity"
    - require:
      - cmd: keystone_syncdb
    - watch:
      - service: apache2

keystone_keystone_endpoint:
  keystone.endpoint_present:
    - name: keystone
    - publicurl: http://{{ hostname }}:5000/v2.0
    - internalurl: http://{{ hostname }}:5000/v2.0
    - adminurl: http://{{ hostname }}:35357/v2.0
    - require:
      - keystone: keystone_keystone_service

keystone_service_tenant:
  keystone.tenant_present:
    - name: service
    - description: "Service Project"
    - require:
      - cmd: keystone_syncdb
      - service: apache2

keystone_admin_tenant:
  keystone.tenant_present:
    - name: admin
    - description: "Admin Project"
    - require:
      - keystone: keystone_service_tenant

keystone_roles:
  keystone.role_present:
    - names: {{ server.roles }}
    - require:
      - keystone: keystone_service_tenant

keystone_admin_user:
  keystone.user_present:
    - name: admin
    - password: password
    - email: root@localhost
    - tenant: admin
    - roles:
        admin:
          - admin
    - require:
      - keystone: keystone_admin_tenant
      - keystone: keystone_roles

# Add additional services here
