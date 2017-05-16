xquery version "1.0-ml";

import module namespace cpf = "http://marklogic.com/cpf" at "/MarkLogic/cpf/cpf.xqy";
import module namespace wfu="http://marklogic.com/workflow-util" at "/app/models/workflow-util.xqy";

declare namespace wf="http://marklogic.com/workflow";

declare variable $cpf:document-uri as xs:string external;
declare variable $cpf:transition as node() external;
declare variable $cpf:options as element() external;

(: Example CPF Pipeline XML:-
<state-transition>
  <annotation>BPMN2 Exclusive Gateway</annotation>
  <state>http://marklogic.com/states/PROCESSNAME__1__0/SomeStep</state>
  <!-- no on success -->
  <on-failure>http://marklogic.com/states/error</on-failure> <!-- could be a failure handling event step -->
  <execute>
    <action>
      <module>/workflowengine/actions/exclusiveGateway.xqy</module>
      <options xmlns="/workflowengine/actions/exclusiveGateway.xqy">
        <wf:namespaces>
          <wf:namespace short="xh" long="http://some/xml/ns" />
        </wf:namespaces>
        <wf:route xmlns:wf="http://marklogic.com/workflow">
          <wf:condition>fn:empty(/some/xpath/resulting/in/boolean)</wf:condition>
          <wf:state>http://marklogic.com/states/PROCESSNAME__1__0/RouteAFirstStep</wf:state>
          <wf:name>Route A</wf:name>
          <wf:description>Something from BPMN2 description field</wf:description>
        </wf:route>
        <wf:route xmlns:wf="http://marklogic.com/workflow">
          <wf:condition>fn:empty(/some/xpath/resulting/in/boolean)</wf:condition>
          <wf:state>http://marklogic.com/states/PROCESSNAME__1__0/RouteBFirstStep</wf:state>
          <wf:name>Route B</wf:name>
          <wf:description>Something from BPMN2 description field</wf:description>
        </wf:route>
        ...
      </options>
    </action>
  </execute>
</state-transition>

  (: TODO handle version 8 javascript conditions :)
:)

try {
  let $map := map:map()
  let $st := fn:current-dateTime()

  let $ns := ($cpf:options/wf:namespaces/wf:namespace,<wf:namespace short="wf" long="http://marklogic.com/workflow" />)
  (: Default namespace is same as process doc :) (: TODO mix in those from BPMN2 doc :)

  (: Evaluate each condition in turn :)


  let $_ :=
    for $route in $cpf:options/wf:route
    return
      if (fn:not(fn:empty(map:get($map,"route")))) then
        ()
      else
        if (fn:not(fn:empty($route/wf:condition))) then
          if (wfu:evaluate($cpf:document-uri,$ns,$route/wf:condition/text())) then
            (: If true, set route choice state :)
            map:put($map,"route",xs:anyURI($route/wf:state/text()))
          else
            ()
        else
          ()

  let $_ :=
    if (fn:empty(map:get($map,"route")) and fn:not(fn:empty($cpf:options/wf:default-route-state)) ) then
      map:put($map,"route",xs:anyURI(xs:string($cpf:options/wf:default-route-state)))
    else ()

  let $_ := xdmp:log("Map of route:-")
  let $_ := xdmp:log($map)


  (: If still none, throw failure message (misconfiguration) :)
  return
    if (fn:empty(map:get($map,"route"))) then
      fn:error(xs:QName(wf:exclusiveGatewayNoRoute),"No route chosen out of exclusive gateway!")
    else
      wfu:complete( $cpf:document-uri, $cpf:transition, map:get($map,"route"), $st )
} catch ($e) {
  wfu:failure( $cpf:document-uri, $cpf:transition, $e, () )
}
