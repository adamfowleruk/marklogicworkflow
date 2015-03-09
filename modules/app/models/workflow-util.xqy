xquery version "1.0-ml";

module namespace m="http://marklogic.com/workflow-util";

import module namespace cpf = "http://marklogic.com/cpf" at "/MarkLogic/cpf/cpf.xqy";
import module namespace sem = "http://marklogic.com/semantics" at "/MarkLogic/semantics.xqy";


import module namespace ss = "http://marklogic.com/search/subscribe" at "/app/models/lib-search-subscribe.xqy";

declare namespace prop = "http://marklogic.com/xdmp/property";
declare namespace wf="http://marklogic.com/workflow";
declare namespace p="http://marklogic.com/cpf/pipelines";
declare namespace error="http://marklogic.com/xdmp/error";

(:
 : Create a new process and activate it.
 :)
declare function m:create($pipelineName as xs:string,$data as element()*,$attachments as element()*) as xs:string {
  let $id := sem:uuid-string() || "-" || xs:string(fn:current-dateTime())
  let $uri := "/workflow/processes/"||$pipelineName||"/"||$id || ".xml"
  let $_ :=
  xdmp:document-insert($uri,
  <wf:process id="{$id}">
    <wf:data>{$data}</wf:data>
    <wf:attachments>{$attachments}</wf:attachments>
    <wf:audit-trail></wf:audit-trail>
    <wf:metrics></wf:metrics>
  </wf:process>,
  xdmp:default-permissions(),
  (xdmp:default-collections(),"http://marklogic.com/workflow/processes")
  )
  return $id
};

(:
 : Create a new process subscription
 :)
declare function m:createSubscription($pipelineName as xs:string,$name as xs:string,$query as element(cts:query)) as xs:string {
  ss:add-alert($name,$query,(),"/app/models/alert-action-process.xqy",(),(<wf:process-name>{$pipelineName}</wf:process-name>))
};

(:
 : Returns a process document with the given id
 :)
declare function m:get($processId as xs:string) as element(wf:process)? {
  fn:collection("http://marklogic.com/workflow/processes")/wf:process[./@id = $processId]
};

(:
 : Returns the (CPF and MarkLogic Workflow) properties fragment for the given process id
 :)
declare function m:getProperties($processId as xs:string) as element(prop:properties)? {
  xdmp:document-properties((fn:collection("http://marklogic.com/workflow/processes")/wf:process[./@id = $processId]/fn:base-uri(.)))
};




(:
 : Returns the specified user, or current user, inbox list. Lists all processes in a UserTask (or subclass thereof)
 :)
declare function m:inbox($username as xs:string?) as element(wf:inbox) {
  <wf:inbox>
  {
    for $process in cts:search(fn:collection("http://marklogic.com/workflow/processes"),
      cts:and-query(
        (: TODO add cpf-active check, wf:status running check, wf:locked-user blank :)
        cts:properties-query(
          cts:element-query(xs:QName("wf:currentStep"),
            cts:element-value-query(xs:QName("wf:assignee"),($username,xdmp:get-current-user())[1])
          )
        )
      ),("unfiltered") (: TODO ordering, prioritisation support, and so on :)
    )
    return
      <wf:task processid="{xs:string($process/wf:process/@id)}">
        {$process}
      </wf:task>
  }
  </wf:inbox>
};






(:
 : This module performs process data document update functions via a high level abstraction.
 :)

declare function m:complete($processUri as xs:string,$transition as node(),$stateOverride as xs:anyURI?,$startTime as xs:dateTime) as empty-sequence() {
  (: Fetch process model doc properties and Update completion time :)
  let $_ := xdmp:document-set-property($processUri,<wf:status>COMPLETE</wf:status>)
  let $_ := m:metric($processUri,$transition/p:state/text(),$startTime,fn:current-dateTime(),fn:true())
  (: Add audit event :)
  let $_ := m:audit($processUri,$transition/p:state/text(),"ProcessEngine","Completed step",())
  return
    (: Call CPF Success with next state :)
    cpf:success($processUri,$transition,$stateOverride)
};

declare function m:failure($processUri as xs:string,$transition as node(),$failureReason as element(error:error)?,$detail as node()*) as empty-sequence() {
  m:audit($processUri,$transition/p:state/text(),"Exception",$failureReason/error:code/text(),($failureReason,$detail))
  ,
  cpf:failure($processUri,$transition,$failureReason,())
};

declare function m:audit($processUri as xs:string,$state as xs:string,$eventCategory as xs:string,$description as xs:string,$detail as node()*) as empty-sequence() {
  (: Perform append operation on process document's audit element :)
  xdmp:node-insert-child(fn:doc($processUri)/wf:process/wf:audit-trail,
    m:audit-create($processUri,$state,$eventCategory,$description,$detail)
  )
};

declare function m:audit-create($processUri as xs:string,$state as xs:string,$eventCategory as xs:string,$description as xs:string,$detail as node()*) as element(wf:audit) {
  <wf:audit><wf:when>{fn:current-dateTime()}</wf:when><wf:category>{$eventCategory}</wf:category><wf:state>{$state}</wf:state><wf:description>{$description}</wf:description><wf:detail>{$detail}</wf:detail></wf:audit>
};

declare function m:metric($processUri as xs:string,$state as xs:string,$start as xs:dateTime,$completion as xs:dateTime,$success as xs:boolean) as empty-sequence() {
  (: Append metric event to internal metrics element :)
  xdmp:node-insert-child(fn:doc($processUri)/wf:process/wf:metrics,
    <wf:metric><wf:state>{$state}</wf:state><wf:start>{$start}</wf:start><wf:finish>{$completion}</wf:finish>
    <wf:duration>{$completion - $start}</wf:duration>
    <wf:success>{$success}</wf:success></wf:metric>
  )
};

declare function m:evaluate($processUri as xs:string,$namespaces as element(wf:namespace)*,$xpath as xs:string) as xs:boolean {
  (: TODO handle version 8 javascript conditions :)
  let $xp :=
    if (fn:substring($xpath,1,1) = "/") then
      'fn:doc("' || $processUri || '")' || $xpath
    else
      $xpath

  (: replacements of shorthand variable names :)
  let $xp := fn:replace($xp,"$wf:process/",'fn:doc("' || $processUri || '")/')
  let $xp := fn:replace($xp, "$processData/",'fn:doc("' || $processUri || '")/wf:data/')

  let $_ := xdmp:log($xp)
  let $ns :=
    for $namespace in $namespaces
    return ($namespace/@short/text(),$namespace/@long/text())
  let $_ := xdmp:log($ns)
  return
    xdmp:with-namespaces($ns, xdmp:eval('declare namespace wf="http://marklogic.com/workflow"; ' || $xp,(),()))
};
