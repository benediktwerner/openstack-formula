{% from "controller/map.jinja" import server, openstack with context %}

controller_start_event:
  event.send:
    - name: formula_status
    - data:
        message: Starting installation on {{ grains.id }}

# BAD HACK, TODO: implement chrony or another ntp
hacky_ntp:
  cmd.run:
    - name: "hwclock --hctosys"

SuSEfirewall2:
  service.dead:
    - enable: False

python-openstackclient:
  pkg.installed

mariadb:
  pkg.installed:
    - pkgs:
      - mariadb
      - mariadb-client
      - python-mysql

/etc/my.cnf.d/mariadb_openstack.cnf:
  file.managed:
    - source: salt://controller/files/mariadb_openstack.cnf
    - require:
      - pkg: mariadb

mysql:
  service.running:
    - enable: True
    - require:
      - file: /etc/my.cnf.d/mariadb_openstack.cnf

{#
postgresql:
  pkg.installed:
    - pkgs:
      - postgresql94
      - postgresql94-server
      - python-psycopg2
  service.running:
    - enable: True
    - require:
      - pkg: postgresql
#}
{# only for telemetry
mongodb:
  pkg.installed: []
  service.running:
    - enable: True
    - require:
      - pkg: mongodb
#}

rabbitmq-server:
  pkg.installed: []
  service.running:
    - enable: True
    - require:
      - pkg: rabbitmq-server

# HACK: RabbitMQ needs some more time, else openstack_user_present will fail
wait_for_rmq:
  module.wait:
    - name: test.sleep
    - length: 5
    - watch:
      - pkg: rabbitmq-server

openstack_user_present:
  rabbitmq_user.present:
    - name: {{ openstack.message_queue.user }}
    - password: {{ openstack.message_queue.password }}
    - force: True
    - perms:
      - '/':
        - '.*'
        - '.*'
        - '.*'
    - require:
      - module: wait_for_rmq

controller_event:
  event.send:
    - name: formula_status
    - data:
        message: Installed controller prerequisites on {{ grains.id }}
