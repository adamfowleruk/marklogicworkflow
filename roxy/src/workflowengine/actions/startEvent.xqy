xquery version "1.0-ml";

import module namespace cpf = "http://marklogic.com/cpf" at "/MarkLogic/cpf/cpf.xqy";
import module namespace wfu="http://marklogic.com/workflow-util" at "/app/models/workflow-util.xqy";

declare namespace wf="http://marklogic.com/workflow";
declare namespace p="http://marklogic.com/cpf/pipelines";

declare variable $cpf:document-uri as xs:string external;
declare variable $cpf:transition as node() external;
declare variable $cpf:options as element() external;

(: A placeholder for an endEvent in a BPMN2 model

<state-transition>
  <annotation>BPMN2 start Event: start1</annotation>
  <state>http://marklogic.com/states/PROCESSNAME__1__0/start1</state>
  <on-success>http://marklogic.com/states/PROCESSNAME__1__0/Task_1</on-success>
  <on-failure>http://marklogic.com/states/error</on-failure> <!-- could be a failure handling event step -->
  <execute>
    <action>
      <module>/workflowengine/actions/startEvent.xqy</module>
      <options xmlns="/workflowengine/actions/startEvent.xqy">
      </options>
    </action>
  </execute>
</state-transition>
:)

try {
  let $st := fn:current-dateTime()
  let $_ := xdmp:log($cpf:transition)
  let $parts := fn:tokenize($cpf:transition/p:state/text(),"/")
  let $_ := xdmp:log($parts)
  let $processinfo := fn:tokenize($parts[fn:last() - 1],"__")
  let $_ := xdmp:log($processinfo)
  return
  (
    (: set initial Workflow properties :)
    xdmp:node-insert-child(fn:doc($cpf:document-uri)/wf:process,attribute title {$parts[fn:last() - 1]}),
    xdmp:node-insert-child(fn:doc($cpf:document-uri)/wf:process,attribute name {$processinfo[1]}),
    xdmp:node-insert-child(fn:doc($cpf:document-uri)/wf:process,attribute major {$processinfo[2]}),
    xdmp:node-insert-child(fn:doc($cpf:document-uri)/wf:process,attribute minor {$processinfo[3]}),
    xdmp:document-add-properties($cpf:document-uri,
      (
        <wf:start>{fn:current-dateTime()}</wf:start>
        ,
        <wf:status>RUNNING</wf:status>
      )
    )
    ,
    wfu:complete( $cpf:document-uri, $cpf:transition, (), $st )
  )
} catch ($e) {
  wfu:failure( $cpf:document-uri, $cpf:transition, $e, () )
}
