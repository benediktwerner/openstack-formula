nova:
  controller:
    host: controller.de.mo
    bind:
      private_address: 127.0.0.1
    database:
      name: nova
      user: nova
      password: password
      host: localhost
    identity:
      host: localhost
      user: nova
      password: password
      tenant: service
    message_queue:
      host: localhost
      user: openstack
      password: password
    glance:
      host: localhost
    network:
      host: 127.0.0.1
      port: 9696
      region: RegionOne
      tenant: service
      user: neutron
      password: password
      metadata_secret: secret

