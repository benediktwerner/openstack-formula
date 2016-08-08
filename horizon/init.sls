openstack-dashboard:
  pkg.installed

horizon_dashboard_conf:
  file.managed:
    - name: /etc/apache2/conf.d/openstack-dashboard.conf
    - source: salt://openstack/horizon/files/openstack-dashboard.conf
    - template: jinja
    - require:
      - pkg: openstack-dashboard

horizon_enable_mod_rewrite:
  cmd.run:
    - name: "a2enmod rewrite"
    - require:
      - file: horizon_dashboard_conf

horizon_enable_mod_ssl:
  cmd.run:
    - name: "a2enmod ssl"
    - require:
      - cmd: horizon_enable_mod_rewrite

horizon_enable_mod_wsgi:
  cmd.run:
    - name: "a2enmod wsgi"
    - require:
      - cmd: horizon_enable_mod_ssl

horizon_local_settings_py:
  file.managed:
    - name: /srv/www/openstack-dashboard/openstack_dashboard/local/local_settings.py
    - source: salt://openstack/horizon/files/local_settings.py
    - template: jinja
    - require:
      - cmd: horizon_enable_mod_wsgi

horizon_enable_services:
  service.running:
    - names:
      - apache2
      - memcached
    - enable: True
    - require:
      - file: horizon_local_settings_py
    - watch:
      - cmd: horizon_enable_mod_rewrite
      - cmd: horizon_enable_mod_ssl
      - cmd: horizon_enable_mod_wsgi
      - file: horizon_dashboard_conf
      - file: horizon_local_settings_py

SuSEfirewall2:
  service.dead:
    - enable: False
