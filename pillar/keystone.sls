keystone:
  server:
    host: controller.de.mo
    service_token: token
    service_tenant: service
    admin_tenant: admin
    admin_name: admin
    admin_password: password
    admin_email: root@localhost
    database:
      name: 'keystone'
      host: 'localhost'
      user: 'keystone'
      password: 'password'
    cache:
      host: localhost
      port: 11211
    service:
      keystone:
        type: identity
        description: OpenStack Identity
#        region: RegionOne
        bind:
          public_port: 5000
          public_path: /v2.0
          internal_port: 5000
          internal_path: /v2.0
          admin_port: 35357
          admin_path: /v2.0
      glance:
        type: image
        description: OpenStack Image service
        bind:
          public_port: 9292
          internal_port: 9292
          admin_port: 9292
        user:
          name: glance
          password: password
      nova:
        type: compute
        description: OpenStack Compute
        bind:
          public_port: 8774
          public_path: /v2/%(tenant_id)s
          internal_port: 8774
          internal_path: /v2/%(tenant_id)s
          admin_port: 8774
          admin_path: /v2/%(tenant_id)s
#          admin_protocol: http
        user:
          name: nova
          password: password
      neutron:
        type: network
        description: OpenStack Networking
        bind:
          public_port: 9696
          internal_port: 9696
          admin_port: 9696
        user:
          name: neutron
          password: password
#    tenant:
#      demo:
#        user:
#          demo1:
#            password: password
#            email: email@de.mo
#            roles:
#              - admin
#          demo2:
#            password: pwd2
