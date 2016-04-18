xquery version "1.0-ml";

declare namespace my="http://marklogic.com/alerts";

import module namespace la = "http://marklogic.com/alerts/alerting" at "/app/models/lib-alerting.xqy";

declare variable $my:vars as map:map external;

la:create-rule(map:get($my:vars,"alert-name"),map:get($my:vars,"query"),map:get($my:vars,"options"))