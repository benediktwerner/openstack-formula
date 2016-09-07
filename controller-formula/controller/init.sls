{% from "controller/map.jinja" import server, openstack with context %}

controller_start_event:
  event.send:
    - name: formula_status
    - data:
        status: Installing controller prerequisites

# BAD HACK, TODO: implement chrony or another ntp
hacky_ntp:
  cmd.run:
    - name: "hwclock --hctosys"

# TODO: Open ports instead of disabling firewall
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
# Should be fixed in the RabbitMQ module, but might be a problem with
# the RabbitMQ service saying he's ready when he really isn't.
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

controller_finished_event:
  event.send:
    - name: formula_status
    - data:
        status: Finished installing controller prerequisites
    - require:
        - rabbitmq_user: openstack_user_present

controller_failed_event:
  event.send:
    - name: formula_status
    - data:
        status: Failed installing controller prerequisites
    - onfail:
        - event: controller_finished_event
