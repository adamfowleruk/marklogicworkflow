xquery version "1.0-ml";

import module namespace cpf = "http://marklogic.com/cpf" at "/MarkLogic/cpf/cpf.xqy";
import module namespace wfu="http://marklogic.com/workflow-util" at "/app/models/workflow-util.xqy";

declare namespace wf="http://marklogic.com/workflow";

declare variable $cpf:document-uri as xs:string external;
declare variable $cpf:transition as node() external;
declare variable $cpf:options as element() external;

(: A dumb blank task in a BPMN2 model

<state-transition>
  <annotation>Generic Task</annotation>
  <state>http://marklogic.com/states/PROCESSNAME__1__0/SomeStep</state>
  <on-success>http://marklogic.com/states/PROCESSNAME__1__0/NextStep</on-success>
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
  wfu:complete( $cpf:document-uri, $cpf:transition, (), fn:current-dateTime() )
} catch ($e) {
  wfu:failure( $cpf:document-uri, $cpf:transition, $e, () )
}
