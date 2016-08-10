{% from "openstack/glance/map.jinja" import server with context %}

# Creating database and db users
glance_database:
  mysql_database.present:
    - name: {{ server.database.name }}

glance_db_user:
  mysql_user.present:
    - name: {{ server.database.user }}
    - host: {{ server.database.host }}
    - password: {{ server.database.password }}
    - require:
      - mysql_database: glance_database
  mysql_grants.present:
    - grant: all privileges
    - database: "{{ server.database.name }}.*"
    - user: {{ server.database.user }}
    - host: {{ server.database.host }}
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

# Installing glance packages
glance_packages:
  pkg.installed:
    - names: {{ server.pkgs }}

# Managing config files
/etc/glance/glance-api.conf:
  file.managed:
    - source: salt://openstack/glance/files/glance-api.conf
    - template: jinja
    - require:
      - pkg: glance_packages

/etc/glance/glance-registry.conf:
  file.managed:
    - source: salt://openstack/glance/files/glance-registry.conf
    - template: jinja
    - require:
      - pkg: glance_packages

# Starting glance services
glance_service:
  service.running:
    - names:
      - openstack-glance-api
      - openstack-glance-registry
    - enable: True
    - require:
      - mysql_grants: glance_db_user
      - mysql_grants: glance_db_user_percent
    - watch:
      - file: /etc/glance/glance-api.conf
      - file: /etc/glance/glance-registry.conf
