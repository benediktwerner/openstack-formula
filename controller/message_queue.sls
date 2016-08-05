rabbitmq-server:
  pkg.installed: []
  service.running:
    - enable: True
    - require:
      - pkg: rabbitmq-server

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
    - require:
      - service: rabbitmq-server

openstack_user_present_failed:
  rabbitmq_user.present:
    - name: openstack
    - password: password
    - force: True
    - perms:
      - '/':
        - '.*'
        - '.*'
        - '.*'
    - onfail:
      - rabbitmq_user: openstack_user_present
