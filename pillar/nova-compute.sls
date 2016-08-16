nova:
  compute:
    bind:
      vnc_address: 192.168.100.132
      vnc_listen: 0.0.0.0
      novnc_base_url: http://controller.de.mo:6080/vnc_auto.html
    message_queue:
      host: controller.de.mo
      user: openstack
      password: password
    identity:
      host: controller.de.mo
      user: nova
      password: password
      tenant: service
    glance:
      host: controller.de.mo
    network:
      host: controller.de.mo
      port: 9696
      region: RegionOne
      tenant: service
      user: neutron
      password: password
