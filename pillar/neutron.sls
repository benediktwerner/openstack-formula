neutron:
  server:
    host: controller.de.mo
    physical_public_interface_name: eth0
    metadata_secret: secret
    database:
      name: neutron
      user: neutron
      password: password
      host: localhost
    identity:
      host: localhost
      region: RegionOne
      user: neutron
      password: password
      tenant: service
    message_queue:
      host: localhost
      user: openstack
      password: password
    compute:
      host: 127.0.0.1
      region: RegionOne
      user: nova
      password: password
      tenant: service
