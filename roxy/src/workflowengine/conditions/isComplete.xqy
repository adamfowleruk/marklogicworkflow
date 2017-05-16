xquery version "1.0-ml";

import module namespace cpf = "http://marklogic.com/cpf" at "/MarkLogic/cpf/cpf.xqy";
import module namespace wfu="http://marklogic.com/workflow-util" at "/app/models/workflow-util.xqy";

declare namespace wf="http://marklogic.com/workflow";
declare namespace prop = "http://marklogic.com/xdmp/property";

declare variable $cpf:document-uri as xs:string external;
declare variable $cpf:transition as node() external;
declare variable $cpf:options as element() external;


let $_ := xdmp:log("isComplete condition check for: " || $cpf:document-uri)
let $ready := xdmp:document-properties($cpf:document-uri)/prop:properties/wf:currentStep/wf:step-status
let $_ := xdmp:log($ready)
let $result := "COMPLETE" eq $ready
let $_ := xdmp:log($result)
return (
   xdmp:log( fn:concat("MarkLogic Workflow isComplete result=", fn:string($result), " for ", $cpf:document-uri) ),
   $result
)

(: End of isComplete.xqy :)
