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
    - source: salt://openstack/controller/files/mariadb_openstack.cnf

mysql:
  service.running:
    - enable: True

mongodb:
  pkg.installed: []
  service.running:
    - enable: True
    - require:
      - pkg: mongodb

rabbitmq-server:
  pkg.installed: []
  service.running:
    - enable: True
    - require:
      - pkg: rabbitmq-server

SuSEfirewall2:
  service.dead:
    - enable: False
