# Wait for other processes to finish.
echo "Sleeping for 1 minute..."
sleep 1m

# Install Azure cli
echo "Installing Azure cli"
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install IoT Edge 1.0.9
echo "Upgrading IoT Edge"
export HSM="https://github.com/Azure/azure-iotedge/releases/download/1.0.9/libiothsm-std_1.0.9-1_ubuntu16.04_amd64.deb"
export IOT="https://github.com/Azure/azure-iotedge/releases/download/1.0.9/iotedge_1.0.9-1_ubuntu16.04_amd64.deb"

curl -L $HSM -o libiothsm-std.deb && sudo dpkg --install --force-all ./libiothsm-std.deb
curl -L $IOT -o iotedge.deb && sudo dpkg --install --force-all ./iotedge.deb

# Install Azure cli IoT extension
echo "Installing Azure cli IoT extension"
az extension add --name azure-iot

# Set iothubowner connection string
export CS=$1
# Set IoT Hub name
export IOTHOST=$2
# Set hostname 
export THISHOST=$3
# Set storage acct connection string
export STORAGE_ACCT_CS=$4
# Set influxdb edge IP address
export INFLUX_IP_EDGE=$5
# Set PLC1 IP address
export PLC1_IP=$6
# Set PLC2 IP address
export PLC2_IP=$7
# Set influxdb cloud IP address
export INFLUX_IP_CLOUD=$8

echo "Connection String:"
echo $CS

# Register device, get primary key, remove quotes, set device primary key.
echo "Registering device"
DEVICE_PRIMARY=$(az iot hub device-identity create --device-id $THISHOST --edge-enabled --login $CS --query "authentication.symmetricKey.primaryKey")
DEVICE_PRIMARY="${DEVICE_PRIMARY%\"}"
export DEVICE_PRIMARY="${DEVICE_PRIMARY#\"}"

# Sets full connection string
export DEVICE_CS="HostName=$IOTHOST;DeviceId=$THISHOST;SharedAccessKey=$DEVICE_PRIMARY"

# Gets private IP of localhost
IP=$(ifconfig eth0 | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p')
echo export IOTEDGE_HOST=http://$IP:15580 >> ~/.bashrc

# Write config file
echo "Writing config file"
export CONFIG_FILE=/etc/iotedge/config.yaml
cat > $CONFIG_FILE <<- EOM
provisioning:
  source: "manual"
  device_connection_string: "$DEVICE_CS"
agent:
  name: "edgeAgent"
  type: "docker"
  env: {}
  config:
    image: "mcr.microsoft.com/azureiotedge-agent:1.0.9"
    auth: {}
hostname: $THISHOST
connect:
  management_uri: "http://$IP:15580"
  workload_uri: "http://$IP:15581"
listen:
  management_uri: "http://$IP:15580"
  workload_uri: "http://$IP:15581"
homedir: "/var/lib/iotedge"
moby_runtime:
  docker_uri: "/var/run/docker.sock"
  network: "azure-iot-edge"
EOM

# Restart IoT Edge
echo "Restarting IoT Edge"
sudo systemctl restart iotedge

# Set Telegraf configuration
echo "Writing telegraf.conf"
cat > telegraf.conf <<- EOM
[global_tags]
  dc = "$THISHOST"

[agent]
  interval = "5s"
  flush_interval = "5s"
 # debug = true

[[outputs.azure_iothub]]
  use_gateway = true

[[outputs.file]]
    files = ["stdout"]

[[outputs.influxdb]]
  name_suffix = "_edge"
  urls = ["http://$INFLUX_IP_EDGE:8086"]
  database = "opcdata"
  precision = "s"

[[inputs.opcua_client]]
  name = "plc1"
  endpoint = "opc.tcp://$PLC1_IP:50000"
  timeout = 30
  security_policy = "None"
  security_mode = "None"
  nodes = [
      {name="SpikeData", namespace="2", identifier_type="s", identifier="SpikeData", data_type="double", description="Randomly generated data"},
      {name="RandomSignedInt32", namespace="2", identifier_type="s", identifier="RandomSignedInt32", data_type="int32", description="Randomly generated data"},
      {name="PositiveTrendData", namespace="2", identifier_type="s", identifier="PositiveTrendData", data_type="float", description="Randomly generated data"},
      {name="NegativeTrendData", namespace="2", identifier_type="s", identifier="NegativeTrendData", data_type="float", description="Randomly generated data"},
      {name="AlternatingBoolean", namespace="2", identifier_type="s", identifier="AlternatingBoolean", data_type="boolean", description="Randomly generated data"},
  ]

[[inputs.opcua_client]]
  name = "plc2"
  endpoint = "opc.tcp://$PLC2_IP:50000"
  timeout = 30
  security_policy = "None"
  security_mode = "None"
  nodes = [
      {name="SpikeData", namespace="2", identifier_type="s", identifier="SpikeData", data_type="double", description="Randomly generated data"},
      {name="RandomSignedInt32", namespace="2", identifier_type="s", identifier="RandomSignedInt32", data_type="int32", description="Randomly generated data"},
      {name="PositiveTrendData", namespace="2", identifier_type="s", identifier="PositiveTrendData", data_type="float", description="Randomly generated data"},
      {name="NegativeTrendData", namespace="2", identifier_type="s", identifier="NegativeTrendData", data_type="float", description="Randomly generated data"},
      {name="AlternatingBoolean", namespace="2", identifier_type="s", identifier="AlternatingBoolean", data_type="boolean", description="Randomly generated data"},
  ]
EOM

# Upload Telegraf config
echo "Pushing telegraf.conf"
az storage blob upload -n telegraf.conf -f telegraf.conf -c public --connection-string $STORAGE_ACCT_CS

# Get file url
CONF_URL=$(az storage blob url -c public -n telegraf.conf --connection-string $STORAGE_ACCT_CS)
CONF_URL="${CONF_URL%\"}"
export CONF_URL="${CONF_URL#\"}"

# Set Telegraf configuration
echo "Writing deployment.json"
cat > deployment.json <<- EOM
{
    "content": {
      "modulesContent": {
        "\$edgeAgent": {
          "properties.desired": {
            "schemaVersion": "1.0",
            "runtime": {
              "type": "docker",
              "settings": {
                "minDockerVersion": "v1.25",
                "loggingOptions": "",
                "registryCredentials": {}
              }
            },
            "systemModules": {
              "edgeAgent": {
                "type": "docker",
                "settings": {
                  "image": "mcr.microsoft.com/azureiotedge-agent:1.0",
                  "createOptions": "{}"
                }
              },
              "edgeHub": {
                "type": "docker",
                "status": "running",
                "restartPolicy": "always",
                "settings": {
                  "image": "mcr.microsoft.com/azureiotedge-hub:1.0",
                  "createOptions": "{\"HostConfig\":{\"PortBindings\":{\"5671/tcp\":[{\"HostPort\":\"5671\"}],\"8883/tcp\":[{\"HostPort\":\"8883\"}],\"443/tcp\":[{\"HostPort\":\"443\"}]}}}"
                }
              }
            },
            "modules": {
              "telegraf": {
                "settings": {
                    "image": "registry.hub.docker.com/chrishaylesnortal/telegraf-demo:1.3.0",
                    "createOptions": "{\"Cmd\":[\"telegraf\",\"--config\",\"$CONF_URL\"]}"
                },
                "type": "docker",
                "version": "1.0",
                "status": "running",
                "restartPolicy": "always"
              }
            }
          }
        },
        "\$edgeHub": {
          "properties.desired": {
            "schemaVersion": "1.0",
            "routes": {
              "upstream": "FROM /messages/* INTO \$upstream"
            },
            "storeAndForwardConfiguration": {
              "timeToLiveSecs": 7200
            }
          }
        }
      }
    }
  }
EOM

# Set deployment
echo "Creating module deployment"
az iot edge set-modules --device-id $THISHOST --content deployment.json --login $CS

if [ $INFLUX_IP_CLOUD != "0.0.0.0" ]
then
  echo "Creating opcdata database on $INFLUX_IP_CLOUD"
  curl -i -XPOST http://$INFLUX_IP_CLOUD:8086/query --data-urlencode "q=CREATE DATABASE opcdata"
fi


echo "Done."