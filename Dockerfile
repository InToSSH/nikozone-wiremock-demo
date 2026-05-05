FROM holomekc/wiremock-gui:latest

COPY wiremock/mappings /home/wiremock/mappings
COPY wiremock/__files /home/wiremock/__files