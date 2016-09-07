{% set server = pillar.keystone.server %}

export OS_PROJECT_DOMAIN_ID=default
export OS_USER_DOMAIN_ID=default
export OS_PROJECT_NAME=admin
export OS_TENANT_NAME=admin
export OS_USERNAME={{ server.admin_name }}
export OS_PASSWORD={{ server.admin_password }}
export OS_AUTH_URL=http://{{ server.host }}:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
