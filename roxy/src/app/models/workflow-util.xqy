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
declare function m:create($pipelineName as xs:string,$data as element()*,$attachments as element()*,$parent as xs:string?,$forkid as xs:string?,$branchid as xs:string?) as xs:string {
  let $id := sem:uuid-string() || "-" || xs:string(fn:current-dateTime())
  let $uri := "/workflow/processes/"||$pipelineName||"/"||$id || ".xml"
  let $_ :=
  xdmp:document-insert($uri,
  <wf:process id="{$id}">
    <wf:data>{$data}</wf:data>
    <wf:attachments>{$attachments}</wf:attachments>
    <wf:audit-trail></wf:audit-trail>
    <wf:metrics></wf:metrics>
    <wf:process-definition-name>{$pipelineName}</wf:process-definition-name>
    {if (fn:not(fn:empty($parent))) then <wf:parent>{$parent}</wf:parent> else ()}
    {if (fn:not(fn:empty($forkid))) then <wf:forkid>{$forkid}</wf:forkid> else ()}
    {if (fn:not(fn:empty($branchid))) then <wf:branchid>{$branchid}</wf:branchid> else ()}
  </wf:process>,
  xdmp:default-permissions(),
  (xdmp:default-collections(),"http://marklogic.com/workflow/processes")
  )
  return $id
};

(:
 : Convenience function to take a few parameters and set up the above call to m:create (removes this logic from multiple functions)
 :)
declare function m:createSubProcess($parentProcessUri as xs:string,$forkid as xs:string,$subProcessStatus as element(wf:branch-status)) as xs:string {
  let $parent := fn:doc($parentProcessUri)/wf:process
  let $pipelineName := xs:string($parent/wf:process-definition-name) || "/" || xs:string($subProcessStatus/wf:branch)
  return m:create($pipelineName,<data>{$parent/wf:data}</data>/*,<data>{$parent/wf:attachments}</data>/*,$parentProcessUri,$forkid,xs:string($subProcessStatus/wf:branch))
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

declare function m:getProcessInstanceAsset($processUri as xs:string,$assetname as xs:string) as node()? {
  let $process := fn:doc($processUri)/wf:process
  return
    m:getProcessAssets($assetname,xs:string($process/@name),xs:string($process/@major),xs:string($process/@minor))[1]
};

declare function m:setProcessAsset($assetname as xs:string,$asset as node(), $processName as xs:string,$major as xs:string?,$minor as xs:string?) as xs:string {
  xdmp:eval(
    'xquery version "1.0-ml";declare namespace wf="http://marklogic.com/workflow";' ||
    'declare variable $wf:processName as xs:string external;' ||
    'declare variable $wf:major as xs:string external;' ||
    'declare variable $wf:minor as xs:string external;' ||
    'declare variable $wf:assetname as xs:string external;' ||
    'declare variable $wf:asset as node() external;' ||
    'let $uri := "/workflowengine/assets/" || fn:string-join(($wf:processName,$wf:major,$wf:minor),"/") || "/" || $wf:assetname ' ||
    'return (xdmp:document-insert($uri,$asset),$uri)'
    , (: TODO security permissions and properties for easy finding :)

      (xs:QName("wf:processName"),$processName,xs:QName("wf:assetname"),$assetname,xs:QName("wf:major"),$major,
       xs:QName("wf:minor"),$minor,xs:QName("wf:asset"),$asset),
      <options xmlns="xdmp:eval">
        <database>{xdmp:modules-database()}</database>
        <isolation>different-transaction</isolation>
      </options>
    )  (: MUST be executed in the modules DB - where the assets live :)
};


declare function m:deleteProcessAsset($assetname as xs:string,$processName as xs:string,$major as xs:string?,$minor as xs:string?) as xs:string {
  xdmp:eval(
    'xquery version "1.0-ml";declare namespace wf="http://marklogic.com/workflow";' ||
    'declare variable $wf:processName as xs:string external;' ||
    'declare variable $wf:major as xs:string external;' ||
    'declare variable $wf:minor as xs:string external;' ||
    'declare variable $wf:assetname as xs:string external;' ||
    'let $uri := "/workflowengine/assets/" || fn:string-join(($wf:processName,$wf:major,$wf:minor),"/") || "/" || $wf:assetname ' ||
    'return (xdmp:document-delete($uri),$uri)'
    , (: TODO security test :)

      (xs:QName("wf:processName"),$processName,xs:QName("wf:assetname"),$assetname,xs:QName("wf:major"),$major,
       xs:QName("wf:minor"),$minor),
      <options xmlns="xdmp:eval">
        <database>{xdmp:modules-database()}</database>
        <isolation>different-transaction</isolation>
      </options>
    )  (: MUST be executed in the modules DB - where the assets live :)
};

declare function m:getProcessAssets($assetname as xs:string?,$processName as xs:string,$major as xs:string?,$minor as xs:string?) as node()* {
  xdmp:eval(
    'xquery version "1.0-ml";declare namespace wf="http://marklogic.com/workflow";' ||
    'declare variable $wf:processName as xs:string external;' ||
    'declare variable $wf:major as xs:string external;' ||
    'declare variable $wf:minor as xs:string external;' ||
    'declare variable $wf:assetname as xs:string external;' ||
    ' (fn:doc("/workflowengine/assets/" || $wf:processName || "/" || $wf:major || "/" || $wf:minor || "/" || $wf:assetname ),' ||
    '  fn:doc("/workflowengine/assets/" || $wf:processName || "/" || $wf:major || "/" || "/" || $wf:assetname ),' ||
    '  fn:doc("/workflowengine/assets/" || $wf:processName || "/" || $wf:assetname )' ||
    ')[1]'
    (: TODO support blank asset name by listing all processes within processName's URI folder :)
    ,
      (xs:QName("wf:processName"),$processName,xs:QName("wf:assetname"),$assetname,xs:QName("wf:major"),$major,xs:QName("wf:minor"),$minor),
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
        <wf:process-data>
        {$process/wf:process}
        </wf:process-data>
        <wf:process-properties>
        {xdmp:document-properties(fn:base-uri($process))}
        </wf:process-properties>
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
        <wf:process-data>
        {$process/wf:process}
        </wf:process-data>
        <wf:process-properties>
        {xdmp:document-properties(fn:base-uri($process))}
        </wf:process-properties>
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
        <wf:process-data>
        {$process/wf:process}
        </wf:process-data>
        <wf:process-properties>
        {xdmp:document-properties(fn:base-uri($process))}
        </wf:process-properties>
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
        <wf:process-data>
        {$process/wf:process}
        </wf:process-data>
        <wf:process-properties>
        {xdmp:document-properties(fn:base-uri($process))}
        </wf:process-properties>
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


  (: check if we're in a subprocess, AND we are completing the last step (_end), and update just our RV status on parent :)
  (: Performance improvement - only update parent if status has changed :)
  let $audit-detail :=
    if (fn:substring($transition/name,fn:string-length($transition/name) - 3) = "_end") then
      m:updateStatusInParent($processUri)
    else ()

  (: clean up BPMN2 activity step properties :)
  let $cs := xdmp:document-properties($processUri)/prop:properties/wf:currentStep
  let $_ := if (fn:not(fn:empty($cs))) then xdmp:node-delete($cs) else ()

  let $_ := m:metric($processUri,$transition/p:state/text(),$startTime,fn:current-dateTime(),fn:true())
  (: Add audit event :)
  let $_ := m:audit($processUri,$transition/p:state/text(),"ProcessEngine","Completed step",$audit-detail)
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























(: STEP SPECIFIC INFO :)




(: BRANCHING, LOOPING, FORKING, AND RENDEZVOUS FUNCTIONS :)
(:
 : Note that the branchid holds a unique ID for this branch INSTANCE not the branch name. Branch name is derived
 : from the pipeline element. Status generally initialised to INPROGRESS. Could become COMPLETE or FAILED or ABANDONED
 :)
declare function m:branch-status($branchid as xs:string, $pipeline as xs:string,$status as xs:string?) as element(wf:branch) {
  <wf:branch-status>
    <wf:branch>{$branchid}</wf:branch>
    <wf:pipeline>{$pipeline}</wf:pipeline>
    <wf:status>{($status,"INPROGRESS")[1]}</wf:status>
  </wf:branch-status>
};

(:
 : Possible for multiple rendezvous methods to be needed. What this is set as will depend upon the cpf:options
 : configuration passed via m:fork and the fork action.
 : Example: All (Wait for all to be complete),
 :          AllTolerant (wait for all to complete, but consider abandoned and failed as complete)
 :          One (The first one causes us to continue - although status updates will continue to be accepted),
 :          None (fire and forget)
 :
 : Contention in status updates avoided for processes that repeatedly fork by using the forkid which is unique per fork.
 :)
declare function m:branches($forkid as xs:string,$branches as element(wf:branch-status)*,$rvmethod as xs:string) as element(wf:branches) {
  <wf:branches>
    <wf:fork>{$forkid}</wf:fork>
    <wf:rendezvous-method>{$rvmethod}</wf:rendezvous-method>
    <wf:status>INPROGRESS</wf:status>
    {$branches}
  </wf:branches>
};

declare function m:fork($processUri as xs:string,$branch-defs as element(wf:branch-definitions)) as empty-sequence() {
  (: Create document instance for each branch (under its current process name's version folder) :)
  (: map over parent URI and (optional) loop count :)
  let $forkid := xs:string(fn:current-dateTime()) || sem:uuid-string()
  let $branches :=
    m:branches($forkid,(
      let $resultMap := map:map()
      let $_ := map:put($resultMap,"atLeastOneBranch",fn:false())
      let $mainBranches :=
        for $bd in $branch-defs/wf:branch-definition
        return
          (: if inclusiveGateway then check fork condition on EACH branch, and only create sub process for true branches :)
          let $doBranch :=
            if ($branch-defs/wf:forkMethod = "CONDITIONAL") then
              if ($bd/wf:default = "true") then
                fn:false()
              else
                let $ns := (<wf:namespace short="wf" long="http://marklogic.com/workflow" />)
                return
                  if (fn:true() = m:evaluate($processUri,$ns,$bd/wf:condition/text())) then
                    (fn:true(),map:put($resultMap,"atLeastOneBranch",fn:true()) )
                  else
                    fn:false()
            else
              fn:true() (: always true if not conditional :)
          return
            if ($doBranch) then
              let $bs := m:branch-status(xs:string($bd/wf:branch), xs:string($bd/wf:pipeline), () )
              let $doc := m:createSubProcess($processUri,$forkid,$bs) (: THIS IS WHAT CREATES THE FORKED SUB PROCESSES :) (: WFU MODULE :)
              return $bs
            else
              ()
      let $defaultBranch :=
        if ($branch-defs/wf:forkMethod = "CONDITIONAL" and fn:false() = map:get($resultMap,"atLeastOneBranch")) then
          (: process default branch now - treat as parallel for simplicity, even though its only ever one route :)
          (: This is for inclusive gateways only :)
          for $bd in $branch-defs/wf:branch-definition[./wf:default = "true"][1]
          return
            let $bs := m:branch-status(xs:string($bd/wf:branch), xs:string($bd/wf:pipeline), () )
            let $doc := m:createSubProcess($processUri,$forkid,$bs) (: THIS IS WHAT CREATES THE FORKED SUB PROCESSES :) (: WFU MODULE :)
            return $bs

        else ()
      return ($mainBranches,$defaultBranch) (: TODO if both of these are empty, throw workflow exception, as per formal spec :)
      ),xs:string($branch-defs/wf:rendezvous-method)
    )

  (: Update parent process' properties to include passed in $branches settings, and parent status to INPROGRESS :)
  let $parent-update-status := xdmp:node-insert-child(xdmp:document-properties($processUri)/prop:properties,
    <wf:currentStep>
      <wf:startTime>{fn:current-dateTime()}</wf:startTime>
      <wf:step-type>fork</wf:step-type>
      <wf:step-status>INPROGRESS</wf:step-status>
    </wf:currentStep>
  )
  let $parent-update-branches := xdmp:document-set-property($processUri,$branches)

  return ()
};

declare function m:updateStatusInParent($childProcessUri as xs:string) as element()* {
  (: Check if parent URI property exists :)
  let $parentProcessUri := xs:string(fn:doc($childProcessUri)/wf:process/wf:parent)
  let $childStatus := xs:string(xdmp:document-properties($childProcessUri)/prop:properties/wf:status)
  let $forkid := xs:string(fn:doc($childProcessUri)/wf:process/wf:forkid)
  let $branchid := xs:string(fn:doc($childProcessUri)/wf:process/wf:branchid)
  return
    if (fn:not(fn:empty($parentProcessUri))) then
      let $update := xdmp:node-replace(
        xdmp:document-properties($parentProcessUri)/prop:properties/wf:branches[./wf:fork = $forkid]/wf:branch-status[./wf:branch = $branchid]/wf:status
        ,
        <wf:status>{$childStatus}</wf:status>
      )
      return
        <wf:synchronisation-details>
          <wf:message>Parent has been updated to reflect child branch instance's completion status</wf:message>
          <wf:parentProcessUri>{$parentProcessUri}</wf:parentProcessUri>
          <wf:childStatus>{$childStatus}</wf:childStatus>
          <wf:forkid>{$forkid}</wf:forkid>
          <wf:branchid>{$branchid}</wf:branchid>
          <wf:sent-status>{$childStatus}</wf:sent-status>
        </wf:synchronisation-details>
    else ()
  (: Update parent branch for this child instance :)
  (: DO NOT Check if parent complete - done in hasRendezvoused condition -
       (don't forget there will be 1 incomplete child - this process instance! ACID!) :)
  (: DO NOT Get parent wf:branches element (with me complete) and return for audit purposes - will break in ONE mode :)

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

declare function m:evaluate($processUri as xs:string,$namespaces as element(wf:namespace)*,$xpath as xs:string) {
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
