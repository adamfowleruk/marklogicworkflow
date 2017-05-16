xquery version "1.0-ml";

import module namespace cpf = "http://marklogic.com/cpf" at "/MarkLogic/cpf/cpf.xqy";
import module namespace wfu="http://marklogic.com/workflow-util" at "/app/models/workflow-util.xqy";

declare namespace wf="http://marklogic.com/workflow";

declare variable $cpf:document-uri as xs:string external;
declare variable $cpf:transition as node() external;
declare variable $cpf:options as element() external;

(: A custom MarkLogic Workflow task that replaces a node in an XML document with a new node

<state-transition>
  <annotation>MarkLogic Node Replace</annotation>
  <state>http://marklogic.com/states/PROCESSNAME__1__0/SomeStep</state>
  <on-success>http://marklogic.com/states/PROCESSNAME__1__0/NextStep</on-success>
  <on-failure>http://marklogic.com/states/error</on-failure> <!-- could be a failure handling event step -->
  <execute>
    <action>
      <module>/workflowengine/actions/mlNodeReplace.xqy</module>
      <options xmlns="http://marklogic.com/workflow">
        <xpath>fn:doc($wf:process/wf:attachments/wf:attachment[@name='Attachment1']/wf:uri/text())/some/other/somens:docnode</xpath>
        <content><!CDATA[<somens:docnode>withNewContent</somens:docnode>]!></content>
        <namespaces>
          <namespace short="somens" long="http://markogic.com/something/somens" />
        </namespaces>
      </options>
    </action>
  </execute>
</state-transition>
:)

try {
  (: Replace the node, evaluating the content as we go :)
  (xdmp:log("IN ML NODE REPLACE ACTION: " || $cpf:document-uri),xdmp:log($cpf:options),
    let $ns := ($cpf:options/wf:namespaces/wf:namespace,<wf:namespace short="wf" long="http://marklogic.com/workflow" />)
    return
      xdmp:node-replace(
        wfu:evaluate($cpf:document-uri,$ns,xs:string($cpf:options/wf:xpath)),
        wfu:evaluate($cpf:document-uri,$ns,xs:string($cpf:options/wf:content))
      )
    ,cpf:success($cpf:document-uri,$cpf:transition,())
  )
  (: Note the state transition is a full path as a string, so in the WF namespace, not the pipeline namespace :)
} catch ($e) {
  wfu:failure( $cpf:document-uri, $cpf:transition, $e, () )
}
