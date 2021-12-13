#!/bin/sh

echo "downloading truststore"

# -------------------------------------------------------------------
# update these to match your Event Endpoint Management instance
# -------------------------------------------------------------------
NAMESPACE=eventendpointmanagement
INSTANCE=eem

echo "\n\033[1;33m getting SSL/TLS details for Event Gateway in...\033[0m"
echo "namespace      : $NAMESPACE"
echo "instance       : $INSTANCE"


# -------------------------------------------------------------------
# verify dependencies are all available
# -------------------------------------------------------------------
echo "\n\033[1;33m checking for script dependencies...\033[0m"
check_dependency () {
  if hash $1 2>/dev/null; then
    echo "verified $1"
  else
    echo "$1 could not be found"
    exit
  fi
}
check_dependency "keytool"
check_dependency "oc"
check_dependency "openssl"


# -------------------------------------------------------------------
# cleanup from previous runs
# -------------------------------------------------------------------
rm eventgateway.p12


# -------------------------------------------------------------------
# get Event Gateway connection address
# -------------------------------------------------------------------
echo "\n\033[1;33m querying openshift for gateway connection address...\033[0m"
GATEWAY_ADDRESS=`oc get route $INSTANCE-egw-event-gw-client -n $NAMESPACE -o jsonpath="{.spec.host}"`
echo "gateway address: $GATEWAY_ADDRESS"


# -------------------------------------------------------------------
# setting up truststore
# -------------------------------------------------------------------
echo "\n\033[1;33m putting the certificate presented by the Gateway into a truststore...\033[0m"
echo -n | openssl s_client -connect $GATEWAY_ADDRESS:443 -servername $GATEWAY_ADDRESS -showcerts | openssl x509 > bootstrap.crt
keytool -import -noprompt \
        -alias bootstrapca \
        -file bootstrap.crt \
        -keystore eventgateway.p12 -storepass password
rm bootstrap.crt


# -------------------------------------------------------------------
# outputting results
# -------------------------------------------------------------------
echo "\n\033[1;33m connection properties:\033[0m"
echo "\033[1m  ssl.truststore.location=eventgateway.p12\033[0m"
echo "\033[1m  ssl.truststore.type=PKCS12\033[0m"
echo "\033[1m  ssl.truststore.password=password\033[0m"
echo "\033[1m  ssl.endpoint.identification.algorithm=\033[0m"
