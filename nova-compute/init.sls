{% from "nova-compute/map.jinja" import compute with context %}

nova_start_event:
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

nova_remove_base_kernel:
  pkg.removed:
    - names: {{ compute.pkgs_removed }}

nova_pkgs:
  pkg.installed:
    - names: {{ compute.pkgs }}
    - require:
      - pkg: nova_remove_base_kernel

/etc/nova/nova.conf:
  file.managed:
    - source: salt://nova-compute/files/nova.conf
    - template: jinja
    - require:
      - pkg: nova_pkgs

nbd:
  kmod.present:
    - persist: True
    - require:
      - pkg: nova_pkgs

nova_services:
  service.running:
    - names: {{ compute.services }}
    - enable: True
    - require:
      - kmod: nbd
    - watch:
      - file: /etc/nova/nova.conf

nova_event:
  event.send:
    - name: formula_status
    - data:
        message: Installed nova compute on {{ grains.id }}
