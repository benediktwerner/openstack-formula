{% from "nova-compute/map.jinja" import compute with context %}

nova_start_event:
  event.send:
    - name: formula_status
    - data:
        message: Installing nova compute

# BAD HACK, TODO: implement chrony or another ntp
hacky_ntp:
  cmd.run:
    - name: "hwclock --hctosys"

# TODO: open ports instead of disabling firewall
SuSEfirewall2:
  service.dead:
    - enable: False

# Installing packages
nova_pkgs:
  pkg.installed:
    - names: {{ compute.pkgs }}

# Managing config file
/etc/nova/nova.conf:
  file.managed:
    - source: salt://nova-compute/files/nova.conf
    - template: jinja
    - require:
      - pkg: nova_pkgs

# Enabling kernel-mod "nbd"
nbd:
  kmod.present:
    - persist: True
    - require:
      - pkg: nova_pkgs

# Starting services
nova_services:
  service.running:
    - names: {{ compute.services }}
    - enable: True
    - require:
      - kmod: nbd
    - watch:
      - file: /etc/nova/nova.conf

nova_finished_event:
  event.send:
    - name: formula_status
    - data:
        status: Finished installing nova compute
    - require:
        - service: nova_services

nova_failed_event:
  event.send:
    - name: formula_status
    - data:
        status: Failed installing nova compute
    - onfail:
        - event: nova_finished_event
