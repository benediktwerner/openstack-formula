openstack_user_present:
  rabbitmq_user.present:
    - name: openstack
    - password: password
    - force: True
    - perms:
      - '/':
        - '.*'
        - '.*'
        - '.*'
