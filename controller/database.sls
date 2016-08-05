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
