{% set keystone_db_pwd = "password" %}
{% set server = {
    'roles': ['admin', 'demo']
  }
%}
{% set connectiondetails = {
    'token': 'token',
    'endpoint': 'http://controller1.de.mo:35356/v2.0'
  }
%}

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

#keystone_salt_config:
#  file.managed:
#    - name: /etc/salt/minion.d/keystone.conf
#    - template: jinja
#    - source: salt://openstack/keystone/files/salt-minion.conf
#    - mode: 600

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

keystone_keystone_service:
  keystone.service_present:
    - name: keystone
    - service_type: identity
    - description: "OpenStack identity"
    - token: {{ connectiondetails.token }}
    - endpoint: {{connectiondetails.endpoint }}
    - require:
      - cmd: keystone_syncdb
      - service: apache2

keystone_keystone_endpoint:
  keystone.endpoint_present:
    - name: keystone
    - publicurl: http://controller.de.mo:5000/v2.0
    - internalurl: http://controller.de.mo:5000/v2.0
    - adminurl: http://controller.de.mo:35357/v2.0
    - token: {{ connectiondetails.token }}
    - endpoint: {{connectiondetails.endpoint }}
    - require:
      - keystone: keystone_keystone_service

keystone_service_tenant:
  keystone.tenant_present:
    - name: service
    - description: "Service Project"
    - token: {{ connectiondetails.token }}
    - endpoint: {{connectiondetails.endpoint }}
    - require:
      - cmd: keystone_syncdb
      - service: apache2

keystone_admin_tenant:
  keystone.tenant_present:
    - name: admin
    - description: "Admin Project"
    - token: {{ connectiondetails.token }}
    - endpoint: {{connectiondetails.endpoint }}
    - require:
      - keystone: keystone_service_tenant

keystone_roles:
  keystone.role_present:
    - names: {{ server.roles }}
    - token: {{ connectiondetails.token }}
    - endpoint: {{connectiondetails.endpoint }}
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
    - token: {{ connectiondetails.token }}
    - endpoint: {{connectiondetails.endpoint }}
    - require:
      - keystone: keystone_admin_tenant
      - keystone: keystone_roles

# Add additional services here
