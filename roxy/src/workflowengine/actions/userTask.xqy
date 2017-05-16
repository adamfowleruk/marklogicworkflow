xquery version "1.0-ml";

import module namespace cpf = "http://marklogic.com/cpf" at "/MarkLogic/cpf/cpf.xqy";
import module namespace wfu="http://marklogic.com/workflow-util" at "/app/models/workflow-util.xqy";

declare namespace wf="http://marklogic.com/workflow";

declare variable $cpf:document-uri as xs:string external;
declare variable $cpf:transition as node() external;
declare variable $cpf:options as element() external;

(: A human (manual) task in a BPMN2 model. We wait at this state until moved onwards by the UI via the REST API

<state-transition>
  <annotation>Generic Task</annotation>
  <state>http://marklogic.com/states/PROCESSNAME__1__0/SomeStep</state>
  <!-- on-success is BLANK - we don't want to go forward automatically once complete -->
  <on-failure>http://marklogic.com/states/error</on-failure> <!-- could be a failure handling event step -->
  <execute>
    <action>
      <module>/workflowengine/actions/task.xqy</module>
      <options xmlns="/workflowengine/actions/task.xqy">
      </options>
    </action>
  </execute>
</state-transition>
:)

try {
  (: Copy the cpf options over to the process' properties document :)
  (xdmp:log("IN USER TASK ACTION: " || $cpf:document-uri),xdmp:log($cpf:options),
  xdmp:document-set-property($cpf:document-uri,
    <wf:currentStep>
      {
        if (fn:not(fn:empty($cpf:options/wf:dynamicUser))) then
          let $ns := ($cpf:options/wf:namespaces/wf:namespace,<wf:namespace short="wf" long="http://marklogic.com/workflow" />)
          return
          (: decide who the user is now :)
          (
            <wf:user>{wfu:evaluate($cpf:document-uri,$ns,xs:string($cpf:options/wf:dynamicUser))}</wf:user>,
            $cpf:options/wf:type,
            $cpf:options/wf:state
          )
        else
          $cpf:options/*
      }
      <wf:startTime>{fn:current-dateTime()}</wf:startTime>
      <wf:step-type>userTask</wf:step-type>
      <wf:step-status>ENTERED</wf:step-status>
    </wf:currentStep>)
    ,cpf:success($cpf:document-uri,$cpf:transition,())
  )
  (: WARNING the above currentStep properties are the MINIMUM required of all late-completing process steps :)
  (: Note the state transition is a full path as a string, so in the WF namespace, not the pipeline namespace :)
} catch ($e) {
  wfu:failure( $cpf:document-uri, $cpf:transition, $e, () )
}
