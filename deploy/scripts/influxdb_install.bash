#!/usr/bin/env bash

# Installing InfluxDB

wget -q https://repos.influxdata.com/influxdata-archive_compat.key
echo '393e8779c89ac8d958f81f942f9ad7fb82a25e133faddaf92e15b16e6ac9ce4c influxdata-archive_compat.key' | sha256sum -c && cat influxdata-archive_compat.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg > /dev/null
echo 'deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg] https://repos.influxdata.com/debian stable main' | sudo tee /etc/apt/sources.list.d/influxdata.list
sudo apt-get update && sudo apt-get install -y influxdb
sudo systemctl unmask influxdb.service
sudo systemctl start influxdb
# Create 'opcdata' database.
curl -XPOST 'http://localhost:8086/query' --data-urlencode 'q=CREATE DATABASE "opcdata"'


# Installing Kapacitor

# Kapacitor provides most of the functionality of Chronograf.
# In particular it is responsible for sending alerts.
# Alerts can be sent using various different services ranging from SMTP to Slack and HipChat.
wget https://dl.influxdata.com/kapacitor/releases/kapacitor_1.5.3_amd64.deb
sudo dpkg -i kapacitor_1.5.3_amd64.deb
sudo systemctl enable kapacitor
sudo systemctl start kapacitor

#Telegraf
# After installing InfluxDB and Kapacitor successfully, we can continue with installing Telegraf.
# Telegraf is responsible for gathering all metrics which will further be visualized through Chronograf.

wget https://dl.influxdata.com/telegraf/releases/telegraf_1.12.2-1_amd64.deb
sudo dpkg -i telegraf_1.12.2-1_amd64.deb
sudo systemctl enable telegraf
sudo systemctl start telegraf

# Installing Chronograf https://portal.influxdata.com/downloads/
wget https://dl.influxdata.com/chronograf/releases/chronograf_1.7.14_amd64.deb
sudo dpkg -i chronograf_1.7.14_amd64.deb
sudo systemctl enable chronograf
sudo systemctl start chronograf

# Installing Grafana https://grafana.com/docs/installation/debian/
sudo apt-get update && sudo apt-get install -y grafana
sudo systemctl enable grafana-server.service
sudo systemctl start grafana-server


