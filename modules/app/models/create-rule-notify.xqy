xquery version "1.0-ml";

declare namespace my="http://marklogic.com/alerts";

import module namespace la = "http://marklogic.com/alerts/alerting" at "/app/models/lib-alerting.xqy";

declare variable $my:alert-name as xs:string external;
declare variable $my:alert-detail as xs:string external;
declare variable $my:content-type as xs:string external;
declare variable $my:notificationurl as xs:string external;
declare variable $my:searchname as xs:string external;
declare variable $my:searchdoc as cts:query external;

la:create-rule-notify($my:alert-name,$my:alert-detail,$my:content-type,$my:notificationurl,$my:searchname,$my:searchdoc)