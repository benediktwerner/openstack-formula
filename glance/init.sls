{% from "glance/map.jinja" import server with context %}

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
glance_service:
  service.running:
    - names: {{ server.services }}
    - enable: True
    - require:
      - mysql_grants: glance_db_user
      - mysql_grants: glance_db_user_percent
    - watch:
      - file: /etc/glance/glance-api.conf
      - file: /etc/glance/glance-registry.conf

glance_download_image:
  cmd.run:
    - name: curl -L {{ server.image.url }} -o /tmp/{{server.image.name }}
    - unless: source /root/admin-openrc.sh && openstack image list | grep {{ server.image.name }}
    - creates: /tmp/{{ server.image.name }}

glance_upload_image:
  cmd.run:
    - name: source /root/admin-openrc.sh && glance image-create --name {{ server.image.name }} --file /tmp/{{server.image.name}} --disk-format {{server.image.disk_format}} --container-format {{server.image.container_format}} --visibility {{server.image.visibility}}
    - unless: source /root/admin-openrc.sh && openstack image list | grep {{ server.image.name }}

glance_event:
  event.send:
    - name: formula_status
    - data:
        message: Installed glance
