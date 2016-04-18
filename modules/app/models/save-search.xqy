xquery version "1.0-ml";

declare namespace my="http://marklogic.com/alerts";

import module namespace la = "http://marklogic.com/alerts/alerting" at "/app/models/lib-alerting.xqy";

declare variable $my:searchdoc as cts:query external;
declare variable $my:searchname as xs:string external;

la:do-save($my:searchdoc,$my:searchname)