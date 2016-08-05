mongodb:
  pkg.installed: []
  service.running:
    - enable: True
    - require:
      - pkg: mongodb
  
