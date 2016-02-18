#!/bin/sh

. ../config/webserver-settings.sh

echo "starting 01-processmodel-create.sh"

curl -v --anyauth --user $WFDESU:$WFDESP -X PUT \
    -d@"../data/examples/bpmn2/015-restapi-tests.bpmn" \
    -H "Content-type: application/xml" -H "Accept: application/xml" \
    "http://$RESTHOST:$RESTPORT/v1/resources/processmodel?rs:name=015-restapi-tests.bpmn" > 01-processmodel-create-out.txt

echo "01-processmodel-create.sh complete"
