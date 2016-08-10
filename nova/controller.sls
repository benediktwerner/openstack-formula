{% from "openstack/nova/map.jinja" import controller with context %}

# Creating database and db users
nova_database:
  mysql_database.present:
    - name: {{ controller.database.name }}

nova_db_user:
  mysql_user.present:
    - name: {{ controller.database.user }}
    - host: {{ controller.database.host }}
    - password: {{ controller.database.password }}
    - require:
      - mysql_database: nova_database
  mysql_grants.present:
    - grant: all privileges
    - database: "{{ controller.database.name }}.*"
    - user: {{ controller.database.user }}
    - host: {{ controller.database.host }}
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

nova_pkgs:
  pkg.installed:
    - names: {{ controller.pkgs }}

/etc/nova/nova.conf:
  file.managed:
    - source: salt://openstack/nova/files/controller.nova.conf
    - template: jinja
    - require:
      - pkg: nova_pkgs

nova_services:
  service.enabled:
    - names: {{ controller.services }}
    - enabled: True
    - watch:
      - file: /etc/nova/nova.conf
