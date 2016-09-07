{% from "horizon/map.jinja" import server with context %}


horizon_start_event:
  event.send:
    - name: formula_status
    - data:
        status: Installing horizon

# Installing horizon packages
horizon_pkgs:
  pkg.installed:
    - names: {{ server.pkgs }}

# Managing config files and enabling apache mods
/etc/apache2/conf.d/openstack-dashboard.conf:
  file.managed:
    - source: salt://horizon/files/openstack-dashboard.conf
    - template: jinja
    - require:
      - pkg: horizon_pkgs

horizon_enable_mod_rewrite:
  cmd.run:
    - name: "a2enmod rewrite"
    - unless: a2enmod -l | grep "rewrite"
    - require:
      - pkg: horizon_pkgs

horizon_enable_mod_ssl:
  cmd.run:
    - name: "a2enmod ssl"
    - unless: a2enmod -l | grep "ssl"
    - require:
      - pkg: horizon_pkgs

horizon_enable_mod_wsgi:
  cmd.run:
    - name: "a2enmod wsgi"
    - unless: a2enmod -l | grep "wsgi"
    - require:
      - pkg: horizon_pkgs

/srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py:
  file.managed:
    - source: salt://horizon/files/local_settings.py
    - template: jinja
    - require:
      - pkg: horizon_pkgs

# Installing Dashboard Branding
openstack-dashboard-theme-SUSE:
  pkg.installed

# Starting horizon services
horizon_services:
  service.running:
    - names: {{ server.services }}
    - enable: True
    - watch:
      - cmd: horizon_enable_mod_rewrite
      - cmd: horizon_enable_mod_ssl
      - cmd: horizon_enable_mod_wsgi
      - file: /etc/apache2/conf.d/openstack-dashboard.conf
      - file: /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py

horizon_finished_event:
  event.send:
    - name: formula_status
    - data:
        status: Finished installing horizon
    - require:
        - service: horizon_services

horizon_failed_event:
  event.send:
    - name: formula_status
    - data:
        status: Failed installing horizon
    - onfail:
        - event: horizon_finished_event
