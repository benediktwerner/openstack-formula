{% from "openstack/nova/map.jinja" import compute with context %}

nova_remove_base_kernel:
  pkg.removed:
    - names: {{ compute.pkgs_removed }}

nova_pkgs:
  pkg.installed:
    - names: {{ compute.pkgs }}

/etc/nova/nova.conf:
  file.managed:
    - source: salt://openstack/nova/files/compute.nova.conf
    - template: jinja
    - require:
      - pkg: nova_pkgs

nbd:
  kmod.present:
    - persist: True

nova_services:
  service.running:
    - names: {{ compute.services }}
    - enable: True
