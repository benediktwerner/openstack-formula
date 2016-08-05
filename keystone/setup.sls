{% set keystone_db_pwd = "password" %}

keystone_database:
  mysql_database.present:
    - name: keystone

keystone_user_localhost:
  mysql_user.present:
    - name: keystone
    - host: localhost
    - password: {{ keystone_db_pwd }}
  mysql_grants.present:
    - grant: all privileges
    - database: "keystone.*"
    - user: keystone
    - host: localhost

keystone_user_percent:
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
  - name: keystone-manage db_sync
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
