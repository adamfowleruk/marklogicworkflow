xquery version "1.0-ml";

import module namespace cpf = "http://marklogic.com/cpf" at "/MarkLogic/cpf/cpf.xqy";
import module namespace wfu="http://marklogic.com/workflow-util" at "/app/models/workflow-util.xqy";

declare namespace wf="http://marklogic.com/workflow";
declare namespace prop = "http://marklogic.com/xdmp/property";

declare variable $cpf:document-uri as xs:string external;
declare variable $cpf:transition as node() external;
declare variable $cpf:options as element() external;

(:
 : Check for all property-update and document-update eventualities that mean we should restart the process.
 :)


try {
  let $_ := xdmp:log("MarkLogic Workflow restart CPF action called for: "||$cpf:document-uri)

  (: 1. Check for external task completion status (step-status = "COMPLETE") :)
  let $_ := xdmp:log("restart condition check for: " || $cpf:document-uri)
  let $ready := xdmp:document-properties($cpf:document-uri)/prop:properties/wf:currentStep/wf:step-status
  let $_ := xdmp:log($ready)
  let $result := "COMPLETE" eq $ready
  let $_ := xdmp:log($result)

  return
    if ($result) then

      let $props := xdmp:document-properties($cpf:document-uri)/prop:properties
      let $_ := xdmp:log($props)
      let $next := xs:string($props/wf:currentStep/wf:state)
      let $_ := xdmp:log("Next state: "||$next)
      let $startTime := xs:dateTime($props/wf:currentStep/wf:startTime)
      return wfu:complete( $cpf:document-uri, $cpf:transition, xs:anyURI($next), $startTime )
    else (
      (: From set-updated-action.xqy in CPF:)

      if (cpf:check-transition($cpf:document-uri,$cpf:transition)) then
        (
          cpf:document-set-last-updated( $cpf:document-uri, fn:current-dateTime() )
          ,
          cpf:success( $cpf:document-uri, $cpf:transition, () )
        )
      else ()

    ) (: do what CPF normally does... :)
} catch ($e) {
  wfu:failure( $cpf:document-uri, $cpf:transition, $e, () )
}
