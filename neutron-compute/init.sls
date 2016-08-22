{% from "neutron-compute/map.jinja" import compute with context %}

# Installing packages
neutron_pkgs:
  pkg.installed:
    - names: {{ compute.pkgs }}

# Managing config files
/etc/neutron/neutron.conf:
  file.managed:
    - source: salt://neutron-compute/files/neutron.conf
    - template: jinja
    - require:
      - pkg: neutron_pkgs

/etc/neutron/plugins/ml2/linuxbridge_agent.ini:
  file.managed:
    - source: salt://neutron-compute/files/linuxbridge_agent.ini
    - template: jinja
    - require:
      - pkg: neutron_pkgs

neutron_services:
  service.running:
    - names: {{ compute.services }}
    - enable: True
    - watch:
      - file: /etc/neutron/neutron.conf
      - file: /etc/neutron/plugins/ml2/linuxbridge_agent.ini

neutron_event:
  event.send:
    - name: formula_status
    - data:
        message: Installed neutron compute on {{ grains.id }}
