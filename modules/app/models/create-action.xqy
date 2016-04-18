xquery version "1.0-ml";

declare namespace my="http://marklogic.com/alerts";

import module namespace la = "http://marklogic.com/alerts/alerting" at "/app/models/lib-alerting.xqy";

declare variable $my:alert-name as xs:string external;
declare variable $my:alert-module as xs:string external;
declare variable $my:db as xs:unsignedLong external;
declare variable $my:options as element()* external;

la:create-action($my:alert-name,$my:alert-module,$my:db, $my:options)