xquery version "1.0-ml";

import module namespace cpf = "http://marklogic.com/cpf" at "/MarkLogic/cpf/cpf.xqy";
import module namespace wfu="http://marklogic.com/workflow-util" at "/app/models/workflow-util.xqy";

declare namespace wf="http://marklogic.com/workflow";
declare namespace error="http://marklogic.com/xdmp/error";

declare variable $cpf:document-uri as xs:string external;
declare variable $cpf:transition as node() external;
declare variable $cpf:options as element() external;

(: The BPMN 2.0 Script Task

WARNING: Invocation of the Script Task must return xs:true for success and xs:false for failure (ERROR).

<state-transition>
  <annotation>Script Task</annotation>
  <state>http://marklogic.com/states/PROCESSNAME__1__0/SomeStep</state>
  <on-success>http://marklogic.com/states/PROCESSNAME__1__0/NextStep</on-success>
  <on-failure>http://marklogic.com/states/error</on-failure> <!-- could be a failure handling event step -->
  <execute>
    <action>
      <module>/workflowengine/actions/scriptTask.xqy</module>
      <options xmlns="http://marklogic.com/workflow">
        <module>/some/path/to/xquery.xqy</module>
      </options>
    </action>
  </execute>
</state-transition>

The module is constructed as follows:-

xquery version "1.0-ml";
declare module namespace me="http://mymodulens";

declare namespace wf="http://marklogic.com/workflow";

declare variable $wf:processuri as xs:string external;

try {
  let $output := (: DO SOMETHING HERE :)
  return xs:true()
} catch ($e) {
  xs:false() (: failure! Process must stop executing. :)
}

:)

try {
  (: TODO support JavaScript as an execution language in 8.0 :)
  (xdmp:log("IN SCRIPT TASK ACTION: " || $cpf:document-uri),xdmp:log($cpf:options),
    if (xdmp:invoke($cpf:options/wf:module/text(),
      (xs:QName("wf:processuri"),$cpf:document-uri,
      <options xmlns="xdmp:eval">
        <isolation>different-transaction</isolation>
      </options>)) then
      cpf:success($cpf:document-uri,$cpf:transition,())
    else
      wfu:failure($cpf:document-uri, $cpf:transition, <error:error>Script returned false for failure</error:error>, () )
      (: TODO check if we need to simply replace the above with a throw statement :)
  )
  (: Note the state transition is a full path as a string, so in the WF namespace, not the pipeline namespace :)
} catch ($e) {
  wfu:failure( $cpf:document-uri, $cpf:transition, $e, () )
}
