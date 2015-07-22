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
 : You must create one or more CPF domains for folders or collections that alerts can be evaluated within.
 :)
declare function m:createAlertingDomain($name as xs:string,$type as xs:string,$path as xs:string,$depth as xs:string) as xs:unsignedLong {
  ss:create-domain($name,$type,$path,$depth,("Status Change Handling","Alerting"),xdmp:database-name(xdmp:modules-database()))
};

(:
 : Create a new process subscription
 :)
declare function m:createSubscription($pipelineName as xs:string,$name as xs:string,$domainname as xs:string,$query as cts:query) as xs:string {
  let $alert-uri := ss:add-alert($name,$query,(),"/app/models/alert-action-process.xqy",xdmp:database-name(xdmp:modules-database()),
    (<wf:process-name>{$pipelineName}</wf:process-name>))
  let $alert-enabled := ss:cpf-enable($alert-uri,$domainname)
  return $alert-uri
};

(:
 : Fetches a process subscription
 :)
declare function m:getSubscription($name as xs:string) as element()? {
  ss:get-alert("/config/alerts/" || $name)
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
  xdmp:document-properties((fn:collection("http://marklogic.com/workflow/processes")/wf:process[./@id = $processId]/fn:base-uri(.)))/prop:properties
};

declare function m:getProcessUri($processId as xs:string) as xs:string? {
  (fn:collection("http://marklogic.com/workflow/processes")/wf:process[./@id = $processId]/fn:base-uri(.))
};

declare function m:getProcessAsset($processUri as xs:string,$assetname as xs:string) as node()? {
  xdmp:eval(
    'xquery version "1.0-ml";declare namespace wf="http://marklogic.com/workflow";' ||
    'declare variable $wf:process as element(wf:process) external;' ||
    'declare variable $wf:assetname as xs:string external;' ||
    '(fn:doc("/workflowengine/assets/" || xs:string($wf:process/@name) || "/" || xs:string($wf:process/@major) || "/" || xs:string($wf:process/@minor) || "/" || $wf:assetname ),' ||
    '  fn:doc("/workflowengine/assets/" || xs:string($wf:process/@name) || "/" || xs:string($wf:process/@major) || "/" || $wf:assetname ),' ||
    '  fn:doc("/workflowengine/assets/" || xs:string($wf:process/@name) || "/" || $wf:assetname )' ||
    ')[1]'
    ,
      (xs:QName("wf:process"),fn:doc($processUri)/wf:process,xs:QName("wf:assetname"),$assetname),
      <options xmlns="xdmp:eval">
        <database>{xdmp:modules-database()}</database>
        <isolation>different-transaction</isolation>
      </options>
    )  (: MUST be executed in the modules DB - where the assets live :)
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
 : Returns the queue contents for the named queue
 :)
declare function m:queue($queue as xs:string) as element(wf:queue) {
  <wf:queue>
  {
    for $process in cts:search(fn:collection("http://marklogic.com/workflow/processes"),
      cts:and-query(
        (: TODO add cpf-active check, wf:status running check, wf:locked-user blank :)
        cts:properties-query(
          cts:element-query(xs:QName("wf:currentStep"),
            cts:element-value-query(xs:QName("wf:queue"),$queue)
          )
        )
      ),("unfiltered") (: TODO ordering, prioritisation support, and so on :)
    )
    return
      <wf:task processid="{xs:string($process/wf:process/@id)}">
        {$process}
      </wf:task>
  }
  </wf:queue>
};

(:
 : Returns the queue contents for the named queue
 :)
declare function m:roleinbox($role as xs:string) as element(wf:queue) {
  <wf:queue>
  {
    for $process in cts:search(fn:collection("http://marklogic.com/workflow/processes"),
      cts:and-query(
        (: TODO add cpf-active check, wf:status running check, wf:locked-user blank :)
        cts:properties-query(
          cts:element-query(xs:QName("wf:currentStep"),
            cts:element-value-query(xs:QName("wf:role"),$role)
          )
        )
      ),("unfiltered") (: TODO ordering, prioritisation support, and so on :)
    )
    return
      <wf:task processid="{xs:string($process/wf:process/@id)}">
        {$process}
      </wf:task>
  }
  </wf:queue>
};

(:
 : Lists all processes, or all those with a specific PROCESS__MAJOR__MINOR name
 :)
declare function m:list($processName as xs:string?) as element(wf:list) {
  <wf:list>
  {
    for $process in cts:search(fn:collection("http://marklogic.com/workflow/processes"),
      cts:and-query(
        if (fn:not(fn:empty($processName))) then
          cts:element-attribute-value-query(xs:QName("wf:process"),xs:QName("title"),$processName)
        else
          cts:not-query(())
      ),("unfiltered") (: TODO ordering, prioritisation support, and so on :)
    )
    return
      <wf:listitem processid="{xs:string($process/wf:process/@id)}">
        {$process}
      </wf:listitem>
  }
  </wf:list>
};




(:
 : This module performs process data document update functions via a high level abstraction.
 : WARNING SHOULD BE CALLED FROM WITHIN A CPF ACTION MODULE ONLY.
 :)

declare function m:complete($processUri as xs:string,$transition as node(),$stateOverride as xs:anyURI?,$startTime as xs:dateTime) as empty-sequence() {
  (: Fetch process model doc properties and Update completion time :)
  (:let $_ := xdmp:document-set-property($processUri,<wf:status>COMPLETE</wf:status>) :)
  let $_ := xdmp:log("In wfu:complete: " || $processUri || ", stateOverride: " || $stateOverride)
  let $_ := xdmp:log("  startTime")
  let $_ := xdmp:log($startTime)
  let $_ := xdmp:log("  transition")
  let $_ := xdmp:log($transition)

  (: clean up BPMN2 activity step properties :)
  let $cs := xdmp:document-properties($processUri)/prop:properties/wf:currentStep
  let $_ := if (fn:not(fn:empty($cs))) then xdmp:node-delete($cs) else ()

  let $_ := m:metric($processUri,$transition/p:state/text(),$startTime,fn:current-dateTime(),fn:true())
  (: Add audit event :)
  let $_ := m:audit($processUri,$transition/p:state/text(),"ProcessEngine","Completed step",())
  return
    (: Call CPF Success with next state :)
    (: ( :)
      cpf:success($processUri,$transition,$stateOverride)
    (: ,cpf:document-set-processing-status($processUri,"updated")) :)
};

(:
 : WARNING SHOULD BE CALLED FROM WITHIN A CPF ACTION MODULE ONLY.
 :)
declare function m:completeById($processId as xs:string,$transition as xs:string,$stateOverride as xs:anyURI?,$startTime as xs:dateTime) as empty-sequence() {
  let $_ := xdmp:log("Calling wfu:completeById: id: " || $processId)
  return m:complete(m:getProcessUri($processId),m:transitionByPath($transition),$stateOverride,$startTime)
};

(:
 : Can be called from out of sequence (non CPF) modules - forces a CPF re-evaluation, then complete, in conjunction with the restart.xqy action
 :)
declare function m:finallyComplete($processId as xs:string,$transition as xs:string) as empty-sequence() {
  let $processUri := m:getProcessUri($processId)
  let $props := xdmp:document-properties($processUri)/prop:properties
  let $_ := m:audit($processUri,$transition,"ProcessEngine","Marking as Complete",())
  return
    (
    xdmp:node-replace($props/wf:currentStep/wf:step-status,<wf:step-status>COMPLETE</wf:step-status>)
    (:,
    xdmp:node-replace($props/cpf:status,<cpf:processing-status>active</cpf:processing-status>)
    :)
    (:
    ),
    xdmp:node-replace($props/cpf:status,<cpf:state>{$props/wf:currentStep/wf:state/text()}</cpf:state>)
    :)
    (:
    ,
    (: god awful hack to test CPF updated status change handling :)
    xdmp:node-insert-after(fn:doc($processUri)/wf:process/wf:data,<tag>You're it</tag>)
    :)
    )
};

(:
 : Used to mark a state as in progress - i.e. the automated task is complete, but we are awaiting on an external
 : action before moving the state to the next state. E.g. human task or awaiting an external document or message.
 :)
declare function m:inProgress($processId as xs:string,$transition as xs:string) as empty-sequence() {
  let $processUri := m:getProcessUri($processId)
  let $_ := m:audit($processUri,$transition,"ProcessEngine","In Progress",())
  return
    xdmp:node-replace(xdmp:document-properties($processUri)/prop:properties/wf:currentStep/wf:step-status,<wf:step-status>IN PROGRESS</wf:step-status>)
};

declare function m:transitionByPath($path as xs:string) as element(p:state-transition)? {
  xdmp:eval('xquery version "1.0-ml";declare namespace m="http://marklogic.com/workflow"; import module namespace p="http://marklogic.com/cpf/pipelines" at "/MarkLogic/cpf/pipelines.xqy";declare variable $m:path as xs:string external;xdmp:unpath($m:path)',
    (xs:QName("wf:path"),$path),
    <options xmlns="xdmp:eval">
      <database>{xdmp:triggers-database()}</database>
      <isolation>different-transaction</isolation>
    </options>
  )
    (:  :)
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

(:
 : The below has been replaced by an eval (m:evaluate), which bypasses the string replacement approach

declare function m:evaluateOLD($processUri as xs:string,$namespaces as element(wf:namespace)*,$xpath as xs:string) as xs:boolean {

  let $_ := xdmp:log("In wfu:evaluate")

  (: TODO handle version 8 javascript conditions :)
  let $xp :=
    if (fn:substring($xpath,1,1) = "/") then
      'fn:doc("' || $processUri || '")' || $xpath
    else
      $xpath

  (: replacements of shorthand variable names :)
  let $xp := fn:replace($xp,"\$wf:process/",'fn:doc("' || $processUri || '")/wf:process/')
  let $xp := fn:replace($xp, "\$processData/",'fn:doc("' || $processUri || '")/wf:process/wf:data/')

  let $_ := xdmp:log("wfu:evaluate: Condition: "||$xp)
  let $ns :=
    for $namespace in $namespaces
    return ($namespace/@short/text(),$namespace/@long/text())
  let $_ := xdmp:log("Namespaces:-")
  let $_ := xdmp:log($ns)

  let $result := xdmp:with-namespaces($ns, xdmp:eval('declare namespace wf="http://marklogic.com/workflow"; ' || $xp,(),()))
  let $_ := xdmp:log("wfu:evaluate: result:-")
  let $_ := xdmp:log($result)

  return
    $result
};
:)

declare function m:evaluate($processUri as xs:string,$namespaces as element(wf:namespace)*,$xpath as xs:string) as item() {
  let $ns :=
    for $namespace in $namespaces
    return
      if (fn:not(fn:empty($namespace/@short/text())) and fn:not(fn:empty($namespace/@long/text()))) then
        "declare namespace " || $namespace/@short/text() || ' = "' || $namespace/@long/text() || '"; '
      else ""
  let $xquery :=
    'xquery version "1.0-ml";declare namespace wf="http://marklogic.com/workflow";' || $ns ||
    'declare variable $wf:process as element(wf:process) external;' ||
    $xpath
  let $_ := xdmp:log($xquery)
  return
    xdmp:eval($xquery,
      (xs:QName("wf:process"),fn:doc($processUri)/wf:process),
      <options xmlns="xdmp:eval">
        <isolation>different-transaction</isolation>
      </options>
    )
};

declare function m:evaluateXml($processUri as xs:string,$namespaces as element(wf:namespace)*,$xmlText as xs:string,$params as node()*) as node()* {
  let $xquery := 'xquery version "1.0-ml";declare namespace wf="http://marklogic.com/workflow";' ||
      'declare variable $wf:process as element(wf:process) external;' || $xmlText
  let $_ := xdmp:log("wfu:evaluateXml: xquery: " || $xquery)
  let $result :=
   xdmp:eval($xquery,
      (xs:QName("wf:process"),fn:doc($processUri)/wf:process), (: TODO accept external params without having blank params of () in the eval call :)
      <options xmlns="xdmp:eval">
        <isolation>different-transaction</isolation>
      </options>
    )
  let $_ := xdmp:log("wfu:evaluateXml: result:-")
  let $_ := xdmp:log($result)
  let $_ := xdmp:log("wfu:evaluateXml: Complete. Returning...")
  return $result
};
