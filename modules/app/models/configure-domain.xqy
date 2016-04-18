xquery version "1.0-ml";declare namespace m="http://marklogic.com/alerts";

import module namespace p="http://marklogic.com/cpf/pipelines" at "/MarkLogic/cpf/pipelines.xqy";
import module namespace dom = "http://marklogic.com/cpf/domains" at "/MarkLogic/cpf/domains.xqy";

declare variable $m:pname as xs:string external;declare variable $m:pnames as xs:string* external;
declare variable $m:mdb as xs:unsignedLong external;
declare variable $m:type as xs:string external;
declare variable $m:path as xs:string external;
declare variable $m:otherpipeline as xs:string external;
declare variable $m:depth as xs:string external;

let $_ := xdmp:log("In eval")

let $pids :=
(xs:unsignedLong(p:pipelines()[p:pipeline-name = "Status Change Handling"]/p:pipeline-id),xs:unsignedLong(p:pipelines()[p:pipeline-name = $m:otherpipeline]/p:pipeline-id))
let $_ := xdmp:log("second point")
let $ds := dom:domain-scope($m:type,$m:path,$m:depth)
let $_ := xdmp:log("third point")
let $ec := dom:evaluation-context($m:mdb,"/")
let $_ := xdmp:log("fourth point")
let $dc := dom:create($m:pname,"Domain for "||$m:pname,
  $ds,$ec,$pids,())
let $_ := xdmp:log("fifth point")
return $dc
