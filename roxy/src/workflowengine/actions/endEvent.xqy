xquery version "1.0-ml";

import module namespace cpf = "http://marklogic.com/cpf" at "/MarkLogic/cpf/cpf.xqy";
import module namespace wfu="http://marklogic.com/workflow-util" at "/app/models/workflow-util.xqy";

declare namespace wf="http://marklogic.com/workflow";

declare variable $cpf:document-uri as xs:string external;
declare variable $cpf:transition as node() external;
declare variable $cpf:options as element() external;

(: A placeholder for an endEvent in a BPMN2 model

<state-transition>
  <annotation>BPMN2 End Event: end</annotation>
  <state>http://marklogic.com/states/PROCESSNAME__1__0/end</state>
  <on-success>http://marklogic.com/states/PROCESSNAME__1__0/_end</on-success>
  <on-failure>http://marklogic.com/states/error</on-failure> <!-- could be a failure handling event step -->
  <execute>
    <action>
      <module>/workflowengine/actions/endEvent.xqy</module>
      <options xmlns="/workflowengine/actions/endEvent.xqy">
      </options>
    </action>
  </execute>
</state-transition>
:)

try {
  let $st := fn:current-dateTime()
  return
  (
    (: set final Workflow properties :)
    xdmp:document-add-properties($cpf:document-uri,
      (
        <wf:end>{fn:current-dateTime()}</wf:end>
      )
    )
    ,
    xdmp:node-replace(xdmp:document-properties($cpf:document-uri)/prop:properties/wf:status,<wf:status>COMPLETE</wf:status>)
    ,
    wfu:complete( $cpf:document-uri, $cpf:transition, (), $st )
  )
} catch ($e) {
  wfu:failure( $cpf:document-uri, $cpf:transition, $e, () )
}
