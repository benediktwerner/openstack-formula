include:
{%- if pillar.neutron.server is defined %}
  - openstack.neutron.server
{%- endif %}
{%- if pillar.neutron.compute is defined %}
  - openstack.neutron.compute
{%- endif %}
