xquery version "1.0-ml";

import module namespace cpf = "http://marklogic.com/cpf" at "/MarkLogic/cpf/cpf.xqy";
import module namespace wfu="http://marklogic.com/workflow-util" at "/app/models/workflow-util.xqy";

declare namespace wf="http://marklogic.com/workflow";
declare namespace prop = "http://marklogic.com/xdmp/property";

declare variable $cpf:document-uri as xs:string external;
declare variable $cpf:transition as node() external;
declare variable $cpf:options as element() external;

try {
  let $st := fn:current-dateTime()
  let $_ := xdmp:log("MarkLogic Workflow generic complete CPF action called for: "||$cpf:document-uri)
  let $props := xdmp:document-properties($cpf:document-uri)/prop:properties
  let $_ := xdmp:log($props)

  (: wf:state in cpf:options MAY contain an override of the next state :)
  let $stateOverride :=
    if (fn:not(fn:empty($cpf:options/wf:state))) then
      xs:anyURI(xs:string($cpf:options/wf:state))
    else ()

  (: Allow state transition to happen :)
  return wfu:complete( $cpf:document-uri, $cpf:transition, $stateOverride, $st )
} catch ($e) {
  wfu:failure( $cpf:document-uri, $cpf:transition, $e, () )
}
