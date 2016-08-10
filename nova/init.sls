include:
{%- if pillar.nova.controller is defined %}
  - openstack.nova.controller
{%- endif %}
{%- if pillar.nova.compute is defined %}
  - openstack.nova.compute
{%- endif %}
