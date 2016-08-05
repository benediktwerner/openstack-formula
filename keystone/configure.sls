keystone_salt_config:
  file.managed:
    - name: /etc/salt/minion.d/keystone.conf
    - template: jinja
    - source: salt://openstack/keystone/files/salt-minion.conf
    - mode: 600

keystone_keystone_service:
  keystone.service_present:
    - name: keystone
    - service_type: identity
    - description: "OpenStack identity"

keystone_keystone_endpoint:
  keystone.endpoint_present:
    - name: keystone
    - publicurl: http://controller.de.mo:5000/v2.0
    - internalurl: http://controller.de.mo:5000/v2.0
    - adminurl: http://controller.de.mo:35357/v2.0
