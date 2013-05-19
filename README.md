abiquo-logstash
===============

Abiquo event input plugin for logstash

Insert plugin into jarfile
 jar -uf logstash-1.1.10-flatjar.jar logstash/inputs/abiquoevents.rb
 
Run logstash
 java -jar logstash-1.1.10-flatjar.jar agent -f abiquoevents.conf

