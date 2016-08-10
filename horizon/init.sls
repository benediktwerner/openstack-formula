{% from "openstack/horizon/map.jinja" import server with context %}

# Installing horizon packages
horizon_pkgs:
  pkg.installed:
    - names: {{ server.pkgs }}

# Managing config files and enabling apache mods
horizon_dashboard_conf:
  file.managed:
    - name: /etc/apache2/conf.d/openstack-dashboard.conf
    - source: salt://openstack/horizon/files/openstack-dashboard.conf
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

horizon_local_settings_py:
  file.managed:
    - name: /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py
    - source: salt://openstack/horizon/files/local_settings.py
    - template: jinja
    - require:
      - pkg: horizon_pkgs

# Starting horizon services
horizon_services:
  service.running:
    - names:
      - apache2
      - memcached
    - enable: True
    - watch:
      - cmd: horizon_enable_mod_rewrite
      - cmd: horizon_enable_mod_ssl
      - cmd: horizon_enable_mod_wsgi
      - file: horizon_dashboard_conf
      - file: horizon_local_settings_py

# Disabling firewall (TODO: instead open correct ports!)
SuSEfirewall2:
  service.dead:
    - enable: False

# Installing Dashboard Branding
openstack-dashboard-theme-SUSE:
  pkg.installed

