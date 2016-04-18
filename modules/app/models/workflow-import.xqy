xquery version "1.0-ml";

module namespace m="http://marklogic.com/workflow-import";
declare namespace wf="http://marklogic.com/workflow";

declare namespace sc="http://www.w3.org/2005/07/scxml";
declare namespace b2="http://www.omg.org/spec/BPMN/20100524/MODEL";


import module namespace p="http://marklogic.com/cpf/pipelines" at "/MarkLogic/cpf/pipelines.xqy";
import module namespace dom = "http://marklogic.com/cpf/domains" at "/MarkLogic/cpf/domains.xqy";

import module namespace la = "http://marklogic.com/alerts/alerting" at "/app/models/lib-alerting.xqy";

import module namespace stack="http://marklogic.com/stack" at "/app/models/lib-stack.xqy";

(: TODO replace following outgoing routes with call to m:b2getNextSteps() :)

(: REST API OR XQUERY PUBLIC API FUNCTIONS :)

declare function m:install-and-convert($doc as node(),$filename as xs:string,$major as xs:string,$minor as xs:string,$enable as xs:boolean?) as xs:string {
  let $_ := xdmp:log("In wfi:install-and-convert")
  (: 1. Save document in to DB :)
  let $uri := "/workflow/models/" || $filename
  let $_ :=
    xdmp:eval('xquery version "1.0-ml";import module namespace m="http://marklogic.com/workflow-import" at "/app/models/workflow-import.xqy";declare variable $m:uri as xs:string external;declare variable $m:doc as node() external;'
      || 'xdmp:document-insert($m:uri,$m:doc,xdmp:default-permissions(),(xdmp:default-collections(),"http://marklogic.com/workflow/model"))'
      ,
      (xs:QName("m:uri"),$uri,xs:QName("m:doc"),$doc),
      <options xmlns="xdmp:eval">
        <isolation>different-transaction</isolation>
      </options>
    )
  (: 2. Convert to CPF :)
  let $pnames := m:convert-to-cpf($uri,$major,$minor)
  let $_ := xdmp:log("In wfi:install-and-convert: pnames:- ")
  let $_ := xdmp:log($pnames)
  let $pcreate :=
    (
      for $resp in $pnames
      let $_ := xdmp:log("Installing domain for " || $resp || "?")
      let $dom :=
        if ($enable) then
          let $pipelineId := m:get-pipeline-id($resp)
          let $_ := xdmp:log("Yes! Installing domain now for pipeline with installed id: " || xs:string($pipelineId))
          return
            m:domain( (: $processmodeluri,$major,$minor, :) $resp,$pipelineId) (: Keep uri, major, minor here in case :)
            (: xdmp:log("In wfi:convert-to-cpf: domain: " || $dom) :)
        else
          ()
      return $resp
    )
  return $pnames[1] (: first is root process :)
};

declare function m:enable($localPipelineId as xs:string) as xs:unsignedLong {
  m:domain($localPipelineId,m:get-pipeline-id($localPipelineId)) (: Keep uri, major, minor here in case :)
  (: TODO Need to fetch child domains too, like enabling with PUT does :)
};

declare function m:get-model-by-name($name as xs:string) as node() {
  let $uri := "/workflow/models/" || $name
  return fn:doc($uri)
};

declare function m:ensureWorkflowPipelinesInstalled() as empty-sequence() {
  (: first check if pipeline does not exist :)
  let $name := "MarkLogic Workflow Initial Selection"
  return
  try {
    let $pexists := xdmp:eval('xquery version "1.0-ml";declare namespace m="http://marklogic.com/workflow"; import module namespace p="http://marklogic.com/cpf/pipelines" at "/MarkLogic/cpf/pipelines.xqy";declare variable $m:name as xs:string external;p:get($m:name)',
      (xs:QName("wf:name"),$name),
      <options xmlns="xdmp:eval">
        <database>{xdmp:triggers-database()}</database>
        <isolation>different-transaction</isolation>
      </options>
    )
    return ()
  } catch ($e) {
    (: Install pipeline as it must be missing :)

    let $failureAction := p:action("/MarkLogic/cpf/actions/failure-action.xqy",(),())
    let $wfInitialPid :=
          xdmp:eval('xquery version "1.0-ml";declare namespace m="http://marklogic.com/workflow"; import module namespace p="http://marklogic.com/cpf/pipelines" at "/MarkLogic/cpf/pipelines.xqy";declare variable $m:name as xs:string external;'
            ||
            'p:create($m:name,$m:name,p:action("/MarkLogic/cpf/actions/success-action.xqy",(),()),p:action("/MarkLogic/cpf/actions/failure-action.xqy",(),()),() (: status transitions :) ,('
            ||
            'p:state-transition(xs:anyURI("http://marklogic.com/states/initial"),"",(),xs:anyURI("http://marklogic.com/states/error"),(),p:action("/workflowengine/actions/workflowInitialSelection.xqy","BPMN2 Workflow initial process step selection",()),())'
            || ') (: state transitions :)) '
            ,
            (xs:QName("wf:name"),$name),
            <options xmlns="xdmp:eval">
              <database>{xdmp:triggers-database()}</database>
              <isolation>different-transaction</isolation>
            </options>
          )
    let $_ := xdmp:log("Installing workflow initial pipeline " || $name)
    let $_ := xdmp:log($wfInitialPid)
    let $wfInitial :=
      xdmp:eval('xquery version "1.0-ml";declare namespace m="http://marklogic.com/workflow"; import module namespace p="http://marklogic.com/cpf/pipelines" at "/MarkLogic/cpf/pipelines.xqy";declare variable $m:name as xs:string external;p:get($m:name)',
        (xs:QName("wf:name"),$name),
        <options xmlns="xdmp:eval">
          <database>{xdmp:triggers-database()}</database>
          <isolation>different-transaction</isolation>
        </options>
      )
    let $_ := xdmp:log("Workflow initial pipeline XML:-")
    let $_ := xdmp:log($wfInitial)
    let $installedPipelinePid :=

      xdmp:eval('xquery version "1.0-ml";declare namespace m="http://marklogic.com/workflow"; import module namespace p="http://marklogic.com/cpf/pipelines" at "/MarkLogic/cpf/pipelines.xqy";declare variable $m:xml as element(p:pipeline) external;p:insert($m:xml)',
        (xs:QName("wf:xml"),$wfInitial),
        <options xmlns="xdmp:eval">
          <database>{xdmp:triggers-database()}</database>
          <isolation>different-transaction</isolation>
        </options>
      )
    return ()
  } (: catching pipeline throwing error if it doesn't exist. We can safely ignore this :)
};


declare function m:convert-to-cpf($processmodeluri as xs:string,$major as xs:string,$minor as xs:string) as xs:string* {
  (: Find document :)
  let $_ := xdmp:log("In wfi:convert-to-cpf")

  (: 1. Create Pipeline from raw process model :)
  (: Determine type from root element :)
  let $pmap :=
    xdmp:eval('xquery version "1.0-ml";import module namespace m="http://marklogic.com/workflow-import" at "/app/models/workflow-import.xqy";declare variable $m:processmodeluri as xs:string external;declare variable $m:major as xs:string external;declare variable $m:minor as xs:string external;m:create($m:processmodeluri,$m:major,$m:minor)',
      (xs:QName("m:processmodeluri"),$processmodeluri,xs:QName("m:major"),$major,xs:QName("m:minor"),$minor),
      <options xmlns="xdmp:eval">
        <isolation>different-transaction</isolation>
      </options>
    )
  let $_ := xdmp:log("In wfi:convert-to-cpf: pipeline map:-")
  let $_ := xdmp:log($pmap)

  let $_ := m:ensureWorkflowPipelinesInstalled()

  (:
   : Get the above to return the pipeline map and domain specs
   : PROCESSNAME__MAJOR__MINOR[/SUBPROCESS] => 1234567890 (aka the PID)
   :
   : IMPLIES
   : Domain: directory @ /workflow/processes/PROCESSNAME__MAJOR__MINOR/SUBPROCESSABC with depth: 0
   :)

  (: 1.5 loop through pmaps :)
  let $pnames := (
    for $pname in map:keys($pmap)
    (:let $docpid := map:get($pmap,$pname):)

    (: 2. Get this pipeline's URI :)
    (: let $puri := "http://marklogic.com/cpf/pipelines/"||xs:string($localPipelineId)||".xml" :)
    let $puri :=
      xdmp:eval('xquery version "1.0-ml";import module namespace p="http://marklogic.com/cpf/pipelines" at "/MarkLogic/cpf/pipelines.xqy";import module namespace m="http://marklogic.com/workflow-import" at "/app/models/workflow-import.xqy";declare variable $m:id as xs:string external;p:get($m:id)/fn:base-uri(.)',
        (xs:QName("m:id"),$pname),
        <options xmlns="xdmp:eval">
          <isolation>different-transaction</isolation>
        </options>
      )
    let $_ := xdmp:log("In wfi:convert-to-cpf: puri: " || $puri)

    (: 3. Install pipeline in modules DB (so that CPF runs it) and get the MODULES DB PID (not content db pid as above) :)
    let $pid :=
      xdmp:eval('xquery version "1.0-ml";import module namespace m="http://marklogic.com/workflow-import" at "/app/models/workflow-import.xqy";declare variable $m:puri as xs:string external;m:install($m:puri)',
        (xs:QName("m:puri"),$puri),
        <options xmlns="xdmp:eval">
          <isolation>different-transaction</isolation>
        </options>
      )

    let $_ := xdmp:log("In wfi:convert-to-cpf: installed pid: " || $pid || " for pname: " || $pname)


    return $pname
  )

  let $_ := xdmp:log("In wfi:convert-to-cpf: pnames:-")
  let $_ := xdmp:log($pnames)

  return $pnames

};


declare function m:subscribe-process($subscriptionName as xs:string, $processuri as xs:string,$query as element(cts:query)) as xs:unsignedLong {
  (: TODO remove existing config with same subscription name, if it exists :)
  la:add-alert($subscriptionName,$query,(),"/app/models/action-process.xqy",xdmp:modules-database(),
    <process-name>{$processuri}</process-name>)
};




declare function m:index-of-string
  ( $arg as xs:string? ,
    $substring as xs:string )  as xs:integer* {

  if (contains($arg, $substring))
  then (string-length(substring-before($arg, $substring))+1,
        for $other in
           m:index-of-string(substring-after($arg, $substring),
                               $substring)
        return
          $other +
          string-length(substring-before($arg, $substring)) +
          string-length($substring))
  else ()
 } ;







(: INTERNAL PRIVATE FUNCTIONS :)

declare function m:create($processmodeluri as xs:string,$major as xs:string,$minor as xs:string) as map:map {
  let $_ := xdmp:log("In wfi:create")

  let $root := fn:doc($processmodeluri)/element()

  let $_ := xdmp:log("local name: "||fn:local-name($root)||" namespace: "||fn:namespace-uri($root))
  (:
  let $pname := $processmodeluri||"__"||$major||"__"||$minor
  let $_ := xdmp:log("pname: " || $pname)
  :)


  let $max := m:index-of-string($processmodeluri,"/")[last()]

  let $start := fn:substring($processmodeluri,$max + 1)

  let $shortname := fn:substring-before($start,".")



  let $name := $shortname || "__" || $major || "__" || $minor (: VERY IMPORTANT :)


  let $_ := xdmp:log("In wfi:create: name: " || $name)

  let $_ := xdmp:log("wfi:create : Now DELETING pipeline(s)")


  let $removeDoc :=
    try {
    (:if (fn:not(fn:empty(p:get($name)))) then:)
      xdmp:eval('xquery version "1.0-ml";declare namespace m="http://marklogic.com/workflow"; import module namespace p="http://marklogic.com/cpf/pipelines" at "/MarkLogic/cpf/pipelines.xqy";declare variable $m:puri as xs:string external;( (: p:remove($m:puri), :) for $pn in p:pipelines()/p:pipeline-name return if (fn:substring(xs:string($pn),1,fn:string-length($m:puri)) = $m:puri) then (xdmp:log("Deleting pipeline: "||xs:string($pn)), p:remove(xs:string($pn)) ) else ()  )',
        (xs:QName("wf:puri"),$name),
        <options xmlns="xdmp:eval">
          <database>{xdmp:database()}</database>
          <isolation>different-transaction</isolation>
        </options>
      )
    (: else
      () :)
    } catch ($e) { () } (: catching pipeline throwing error if it doesn't exist. We can safely ignore this :)

  (: NOTE above also removes all child pipelines too - those starting with PROCESS__MAJOR__MINOR :)
  let $_ := xdmp:log("wfi:create : Now recreating pipeline(s)")

  let $pmap :=
        xdmp:eval('xquery version "1.0-ml";import module namespace m="http://marklogic.com/workflow-import" at "/app/models/workflow-import.xqy";'
          || 'declare variable $m:pname as xs:string external;'
          || 'declare variable $m:root as element() external;'
          || 'm:do-create($m:pname,$m:root)'
          ,
          (xs:QName("m:pname"),$name,xs:QName("m:root"),$root),
          <options xmlns="xdmp:eval">
            <database>{xdmp:database()}</database>
            <isolation>different-transaction</isolation>
          </options>
        ) (: TODO handle failure gracefully :)

  return
    $pmap


};

declare function m:do-create($pipelineName as xs:string,$root as element()) as map:map {
  let $_ := xdmp:log("In wfi:do-create: pipelineName: " || $pipelineName)
  return

    if (fn:local-name($root) = 'scxml' and fn:namespace-uri($root) = 'http://www.w3.org/2005/07/scxml') then
      (: Call appropriate conversion function :)

      (xdmp:log("got scxml"),m:scxml-to-cpf($pipelineName, $root))

    else if (fn:local-name($root) = 'definitions' and fn:namespace-uri($root) = 'http://www.omg.org/spec/BPMN/20100524/MODEL') then

      (xdmp:log("got bpmn2"),m:bpmn2-to-cpf($pipelineName,$root))

      else
        (: if not supported throw an error :)
        (xdmp:log("got unknown"),0)
};





(: ASync CPF utility routines :)

declare function m:get-pipeline-id($pname as xs:string) as xs:unsignedLong {
    xdmp:eval(
     'xquery version "1.0-ml";declare namespace m="http://marklogic.com/workflow"; ' ||
     'import module namespace p="http://marklogic.com/cpf/pipelines" at "/MarkLogic/cpf/pipelines.xqy"; ' ||
     'declare variable $m:processmodeluri as xs:string external; xs:unsignedLong(p:get($m:processmodeluri)/p:pipeline-id)'
     ,
      (xs:QName("wf:processmodeluri"),$pname),
      <options xmlns="xdmp:eval">
        <database>{xdmp:triggers-database()}</database>
        <isolation>different-transaction</isolation>
      </options>
    )
};

declare function m:install($puri as xs:string) as xs:unsignedLong {
  let $_ := xdmp:log("In wfi:install: puri: " || $puri)
  let $pxml := fn:doc($puri)/p:pipeline

  (: check if pipeline already exists, and recreate :)
  let $remove :=
    try {
    if (fn:not(fn:empty(p:get($puri)))) then
      let $_ := xdmp:log("wfi:install: Removing pipeline config: " || $puri)
      return
      xdmp:eval('xquery version "1.0-ml";declare namespace m="http://marklogic.com/workflow"; import module namespace p="http://marklogic.com/cpf/pipelines" at "/MarkLogic/cpf/pipelines.xqy";declare variable $m:puri as xs:string external;( (: p:remove($m:puri), :) for $pn in p:pipelines()/p:pipeline-name return if (fn:substring(xs:string($pn),1,fn:string-length($m:puri)) = $m:puri) then (xdmp:log("Deleting pipeline: "||xs:string($pn)), p:remove(xs:string($pn)) ) else ()  )',
        (xs:QName("wf:puri"),$puri),
        <options xmlns="xdmp:eval">
          <database>{xdmp:triggers-database()}</database>
          <isolation>different-transaction</isolation>
        </options>
      )
    else
      ()
    } catch ($e) { () } (: catching pipeline throwing error if it doesn't exist. We can safely ignore this :)

  let $_ := xdmp:log("wfi:install: Adding pipeline config: " || $puri)

  (: Recreate pipeline :)
  return
    xdmp:eval('xquery version "1.0-ml";declare namespace m="http://marklogic.com/workflow"; import module namespace p="http://marklogic.com/cpf/pipelines" at "/MarkLogic/cpf/pipelines.xqy";declare variable $m:pxml as element(p:pipeline) external;p:insert($m:pxml)',
      (xs:QName("wf:pxml"),$pxml),
      <options xmlns="xdmp:eval">
        <database>{xdmp:triggers-database()}</database>
        <isolation>different-transaction</isolation>
      </options>
    )
};


declare function m:domain((: $processmodeluri as xs:string,$major as xs:string,$minor as xs:string, :) $pname as xs:string,$pid as xs:unsignedLong) as xs:unsignedLong {

  let $_ := xdmp:log("In wfi:domain")

  (: let $pname := $processmodeluri||"__"||$major||"__"||$minor :)
  (: TODO Add all OOTB CPF pipelines to this domain too :)

  let $mdb := xdmp:modules-database()
  let $_ := xdmp:log("pname: " || $pname || ", pid: " || xs:string($pid))

  (: check if domain already exists and recreate :)
  let $remove :=
    try {
    if (fn:not(fn:empty(
      xdmp:eval(
       'xquery version "1.0-ml";declare namespace m="http://marklogic.com/workflow"; import module namespace dom = "http://marklogic.com/cpf/domains" at "/MarkLogic/cpf/domains.xqy";declare variable $m:processmodeluri as xs:string external; dom:get($m:processmodeluri)'
       ,
        (xs:QName("wf:processmodeluri"),$pname),
        <options xmlns="xdmp:eval">
          <database>{xdmp:triggers-database()}</database>
          <isolation>different-transaction</isolation>
        </options>
      )
     ))) then

     let $_ := xdmp:log(" GOT DOMAIN TO REMOVE")
     return
      xdmp:eval(
        'xquery version "1.0-ml";declare namespace m="http://marklogic.com/workflow"; import module namespace dom = "http://marklogic.com/cpf/domains" at "/MarkLogic/cpf/domains.xqy";declare variable $m:processmodeluri as xs:string external;'
        ||
        'dom:remove($m:processmodeluri)'
        ,
        (xs:QName("wf:processmodeluri"),$pname),
        <options xmlns="xdmp:eval">
          <database>{xdmp:triggers-database()}</database>
          <isolation>different-transaction</isolation>
        </options>
      )
    else
      ()
    } catch ($e) { ( xdmp:log("Error trying to remove domain: " || $pname || " ignoring and carrying on (it probably doeesn't exist yet!)") ) } (: catching domain throwing error if it doesn't exist. We can safely ignore this :)

  (: Configure domain :)
  return
    xdmp:eval(
      'xquery version "1.0-ml";declare namespace m="http://marklogic.com/workflow"; import module namespace p="http://marklogic.com/cpf/pipelines" at "/MarkLogic/cpf/pipelines.xqy"; import module namespace dom = "http://marklogic.com/cpf/domains" at "/MarkLogic/cpf/domains.xqy";declare variable $m:pname as xs:string external;declare variable $m:pid as xs:unsignedLong external;declare variable $m:mdb as xs:unsignedLong external;'
      ||
      '(xdmp:log("calling dom:create for " || $m:pname), '
      ||
      'dom:create($m:pname,"Execute process given a process data document for "||$m:pname,'
      ||
      'dom:domain-scope("directory","/workflow/processes/"||$m:pname||"/","1"),dom:evaluation-context($m:mdb,"/"),((for $pipe in p:pipelines()[p:pipeline-name = ("Status Change Handling","MarkLogic Workflow Initial Selection")]/p:pipeline-id return xs:unsignedLong($pipe)),$m:pid),())'
      ||
      ')'
      ,
      (xs:QName("wf:pid"),$pid,xs:QName("wf:mdb"),$mdb,xs:QName("wf:pname"),$pname),
      <options xmlns="xdmp:eval">
        <database>{xdmp:triggers-database()}</database>
        <isolation>different-transaction</isolation>
      </options>
    )
};











(: SOURCE CONVERSION FUNCTIONS :)

(:
 : See http://www.w3.org/TR/scxml/
 :)
declare function m:scxml-to-cpf($pipelineName as xs:string, $doc as element(sc:scxml)) as map:map  {
  (: Convert the SCXML process model to a CPF pipeline and insert (create or replace) :)
  let $_ := xdmp:log("in m:scxml-to-cpf()")
  let $initial :=
    if (fn:not(fn:empty($doc/@initial))) then
      $doc/sc:state[./@id = $doc/@initial]
    else
      $doc/sc:state[1]

  (: NB major and minor version not needed because this forms part of the process model document URI :)

  (: remove start and extension to get pname - /processengine/models/NAME/MAJOR/MINOR/model.xml :)
  (: let $pname := $processmodeluri||"__"||$major||"__"||$minor :)

  let $failureAction := p:action("/MarkLogic/cpf/actions/failure-action.xqy",(),())
  let $failureState := xs:anyURI("http://marklogic.com/states/error")

  (: create entry CPF action :)
  (: Link to initial state action :)

  let $pid :=
    p:create($pipelineName,$pipelineName,
      p:action("/MarkLogic/cpf/actions/success-action.xqy",(),()),
      $failureAction,(),
      (
          p:state-transition(xs:anyURI("http://marklogic.com/states/initial"),
            "Standard placeholder for initial state",xs:anyURI("http://marklogic.com/states/"||$pipelineName||"/"||xs:string($initial/@id)),
            $failureState,(),(),()
          )
          ,

          for $state in $doc/sc:state
          return
            p:state-transition(xs:anyURI("http://marklogic.com/states/"||$pipelineName||"/"||xs:string($state/@id)),
              "",xs:anyURI("http://marklogic.com/states/"||$pipelineName||"/"||xs:string($state/sc:transition/@target) ),
              $failureState,(),(),()
            )

          ,
          p:state-transition(xs:anyURI("http://marklogic.com/states/"||$pipelineName||"/"||xs:string($doc/sc:final/@id) ),
            "Standard placeholder for final state",xs:anyURI("http://marklogic.com/states/done"),
            $failureState,(),(),()
          )
      ) (: state transition list :)
    ) (: pcreate :)
  let $map := map:map()
  let $_ := map:put($map,$pipelineName,$pid)
  return $map
};














(:
Example:-

<bpmn2:definitions xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:bpmn2="http://www.omg.org/spec/BPMN/20100524/MODEL" xmlns:bpmndi="http://www.omg.org/spec/BPMN/20100524/DI" xmlns:dc="http://www.omg.org/spec/DD/20100524/DC" xmlns:di="http://www.omg.org/spec/DD/20100524/DI" id="Definitions_1" targetNamespace="http://marklogic.com/workflow">
  <bpmn2:process id="two_sample_transitions" name="Default Process">
    <bpmn2:startEvent id="StartEvent_1" name="Start">
      <bpmn2:outgoing>SequenceFlow_2</bpmn2:outgoing>
    </bpmn2:startEvent>
    <bpmn2:sequenceFlow id="SequenceFlow_2" sourceRef="StartEvent_1" targetRef="Task_1"/>
    <bpmn2:task id="Task_2" name="InProgress">
      <bpmn2:incoming>SequenceFlow_3</bpmn2:incoming>
      <bpmn2:outgoing>SequenceFlow_4</bpmn2:outgoing>
    </bpmn2:task>
    <bpmn2:sequenceFlow id="SequenceFlow_4" sourceRef="Task_2" targetRef="Task_3"/>
    <bpmn2:task id="Task_1" name="Open">
      <bpmn2:incoming>SequenceFlow_2</bpmn2:incoming>
      <bpmn2:outgoing>SequenceFlow_3</bpmn2:outgoing>
    </bpmn2:task>
    <bpmn2:sequenceFlow id="SequenceFlow_3" sourceRef="Task_1" targetRef="Task_2"/>
    <bpmn2:task id="Task_3" name="Closed">
      <bpmn2:incoming>SequenceFlow_4</bpmn2:incoming>
      <bpmn2:outgoing>SequenceFlow_5</bpmn2:outgoing>
    </bpmn2:task>
    <bpmn2:sequenceFlow id="SequenceFlow_5" sourceRef="Task_3" targetRef="EndEvent_1"/>
    <bpmn2:endEvent id="EndEvent_1" name="Finish">
      <bpmn2:incoming>SequenceFlow_5</bpmn2:incoming>
    </bpmn2:endEvent>
  </bpmn2:process>
:)


declare function m:bpmn2-to-cpf($pname as xs:string, $doc as element(b2:definitions)) as map:map  {

  (: Convert the process model to a CPF pipeline and insert (create or replace) :)
  let $_ := xdmp:log("in m:bpmn2-to-cpf()")
  let $start := $doc/b2:process[1] (: TODO process all processes, not just the first :)
  let $_ := xdmp:log($start)
  (: fixed below so start isn't necessarily the task - should it be the startEvent instead? :)
  let $initial := $start/b2:startEvent[1] (: is more than one valid? :)
  (: let $initial := $start/b2:task[./@id = $start/b2:sequenceFlow[./@id = $doc/b2:process/b2:startEvent/b2:outgoing]/@targetRef]:)

  (: NB major and minor version not needed because this forms part of the process model document URI :)

  (: remove start and extension to get pname - /processengine/models/NAME/MAJOR/MINOR/model.xml :)
  (: let $pname := $processmodeluri||"__"||$major||"__"||$minor :)

  let $failureAction := p:action("/MarkLogic/cpf/actions/failure-action.xqy",(),())
  let $failureState := xs:anyURI("http://marklogic.com/states/error")

  (: TODO determine if initial step is an incoming event step for Document Created or Document Updated event (alert has fired the process) :)



  let $pipelineMap := map:map()
  let $stepMap := map:map()
  let $pipelineSteps := map:map()
  let $parents := map:map()
  let $_ := map:put($parents,$pname,$pname) (: Prevents empty set in map get for top level processes :)
  let $callStack := map:map()
  (:
   : MODELPANE_FIRSTSTEPNAME => p:create result (long?)
   :)
  let $createOut := m:b2pipeline($pname,(), $doc, $start, $initial,$failureAction,$failureState,$pipelineMap,$stepMap,$pipelineSteps,$parents,$callStack) (: TODO allow start event to be any gateway with no incoming route :)
  return
    $pipelineMap

};

declare function m:b2pipeline($rootName as xs:string, $parentStep as xs:string?, $doc as element(b2:definitions),$process as element(b2:process),
    $initial as element(), $failureAction,$failureState,$pipelineMap as map:map,$stepMap as map:map,$pipelineSteps as map:map,$parents as map:map,$callStack as map:map) as xs:unsignedLong {
  let $_ := xdmp:log("In m:b2pipeline()")
  let $pname := fn:string-join(($rootName,$parentStep),"/")
  let $_ := xdmp:log("m:b2pipeline: pname: " || $pname)
  let $_ := xdmp:log("initial:-")
  let $_ := xdmp:log($initial)
  (: i.e. PROCNAME or PROCNAME/FORKTASKNAME :)

  (: Step through process from initial step onwards :)
  let $pipeline :=
  p:create($pname,$pname,
    p:action("/MarkLogic/cpf/actions/success-action.xqy",(),()),
    $failureAction,
    (
      p:status-transition("updated","Restart process on external action",() (: success :), $failureState,500,
        p:action("/workflowengine/actions/restart.xqy",
          "Check for restarting process.",() (: options :)
        )
        ,
        () (: rules :)
      )
    ) (: status transitions :)
    ,
    (

        (: create entry CPF action :)
        (: Link to initial state action :)
        (:)(
          if (fn:not(fn:empty($parentStep))) then

          :)

(: NOTE: I suspect this is (NB IT IS) required for each pipeline, as technically each will have its own domain watching its own
   process' or sub-process' folder - not be invoked directly via the main process - each is independent with its own tracking doc :)
            p:state-transition(xs:anyURI("http://marklogic.com/states/"||$pname||"__start"), (: TOP LEVEL PROCESS ONLY!!! :)
              "Standard placeholder for initial state",xs:anyURI("http://marklogic.com/states/"||$pname||"/"||xs:string($initial/@id)),
              $failureState,(),(),()
            )
            (:
          else ()
        ):)
        ,

        let $_ := m:b2walkFrom($rootName,$parentStep,$doc,$process,xs:string($initial/@id),$failureAction,$failureState,$pipelineMap,$stepMap,$pipelineSteps,$parents,$callStack)
        return
          m:b2deduplicate(map:get($pipelineSteps,$pname))
        ,
        p:state-transition(xs:anyURI("http://marklogic.com/states/"||$pname||"__end"),
          "Standard placeholder for final state",xs:anyURI("http://marklogic.com/states/done"),
          $failureState,(),(),()
        )

    ) (: state transition list :)
  ) (: pcreate :)

  let $mapin := map:put($pipelineMap,$pname,$pipeline)
  return $pipeline (: maintains compatibility with previous version of importer - could be removed :)

};

(: Another horrible, horrible hack because forks within forks seem to confuse the importer :)
declare function m:b2deduplicate($transitions as element()*) as element()* {
  (: Loop through states and don't include ones already processed :)
  let $values := map:map()
  let $doit :=
    for $state in $transitions
    let $id := xs:string($state/p:state)
    return
      if (fn:not(map:contains($values,$id))) then
        map:put($values,$id,$state)
      else ()
  let $retVals :=
    for $key in map:keys($values)
    return map:get($values,$key)
  return $retVals
};

declare function m:b2subPipeline($rootName as xs:string,$parentName as xs:string, $doc as element(b2:definitions),$process as element(b2:process),
    $parentStateId as xs:string,$parentState as element(),$parentPname as xs:string,
    $nextState as element(),$failureAction,$failureState,$pipelineMap as map:map,$stepMap as map:map,$pipelineSteps as map:map,$parents as map:map,$callStack as map:map) as empty-sequence() {
  let $pname := fn:string-join(($rootName,$parentName,xs:string($nextState/@id)),"/")
  (: Check that pipeline does not already exist (IMPORTANT - AVOIDS INFINITE LOOPS IN IMPORTER) :)

  let $_ := map:put($parents,$pname,fn:string-join(($rootName,$parentPname),"/") )

  (:
   : TODO problem is that parentName is the parent STEP not the parent CPF Pipeline pname
   :      We need to ensure that we put the parent pipeline's pname in to the $parents map
   :)

  let $_ := xdmp:log("wfi:b2subPipeline: pname for next state: " || $pname || " , parent: " ||
    fn:string-join(($rootName,$parentPname),"/") || " rootName: " || $rootName || ", parentPname: " || $parentPname)

  let $newPipeline :=
    if (fn:empty(map:get($pipelineMap,$pname))) then
      (: Sub process has not yet been created, so create it :)
      (: Put current (parent) level information on stack :)
      let $thisLevel :=
        <frame>
          <rootName>{$rootName}</rootName>
          <pname>{$parentPname}</pname>
          <stateId>{xs:string($parentState/@id)}</stateId>
          <processId>{xs:string($process/@id)}</processId>
        </frame>
      let $newStack := map:new($callStack)
      let $_ := stack:push($newStack,$thisLevel)
      return m:b2pipeline($rootName,(:fn:string-join(($parentName,xs:string($nextState/@id)),"/"):) xs:string($nextState/@id) ,
        $doc,$process,$nextState,$failureAction,$failureState,$pipelineMap,$stepMap,$pipelineSteps,$parents,$newStack)
    else ()

  return ()
};

declare function m:map-append($map as map:map,$key as xs:string,$el as item()*) as empty-sequence() {
  (
    xdmp:log("wfi:map-append: $key: " || $key || ", $el:-")
    ,
    xdmp:log($el)
    ,
    xdmp:log("wfi:map-append map key contents before:-")
    ,
    xdmp:log(map:get($map,$key))
    ,
    xdmp:log("wfi:map-append adding data for key: " || $key)
    ,
    map:put($map,$key,( map:get($map,$key),$el ))
    ,
    xdmp:log("wfi:map-append map key contents after:-")
    ,
    xdmp:log(map:get($map,$key))
  )
};

declare function m:b2walkFrom($rootName as xs:string,$parentStep as xs:string?, $doc as element(b2:definitions),$process as element(b2:process),$nextStep as xs:string,
    $failureAction,$failureState,$pipelineMap as map:map,$stepMap as map:map,$pipelineSteps as map:map,$parents as map:map,$callStack as map:map) as element()* {

  let $_ := xdmp:log("In m:b2walkFrom()")
  let $_ := xdmp:log("rootName: " || $rootName)
  let $_ := xdmp:log("parentStep: " || $parentStep)
  let $_ := xdmp:log("nextstep: " || $nextStep)
  (: Could return state-transitions, conditions, status-transitions, or nothing :)
  let $me := $process/element()[./@id = $nextStep]
  let $pname :=
    if ($rootName = $parentStep or "" = $parentStep) then
      $rootName
    else
      fn:string-join(($rootName,$parentStep),"/")

  let $_ := xdmp:log("m:b2pipeline: Step:-")
  let $_ := xdmp:log($me)
  let $_ := xdmp:log($me/local-name(.))
  let $_ := xdmp:log($pname)
  return
  (: need to keep a map of all processed steps by ID in the doc, and not walk them if already processed :)
  if (fn:not(map:contains($stepMap,xs:string($me/@id))) or
      ($me/local-name(.) = ("parallelGateway","inclusiveGateway") and $me/@gatewayDirection = "Converging") (: Once per fork :)
     ) then
    let $stepDef :=
      try {
        xdmp:apply(xdmp:function(xs:QName("m:b2" || xs:string($me/local-name(.)))),
          $rootName,$parentStep,$pname,$doc,$process,$me,$failureAction,$failureState,$pipelineMap,$stepMap,
          $pipelineSteps,$parents,$callStack)
      } catch ($e) {
        (
          xdmp:log("wfi:b2walkFrom: STEP NOT RECOGNISED!!!") (: returns empty sequence :)
          ,
          xdmp:log($e)
        )
      }
    (:
    if ($me/local-name(.) = "startEvent") then
      m:b2startEvent($rootName,$parentStep,$pname,$doc,$process,$me,$failureAction,$failureState,$pipelineMap,$stepMap,$pipelineSteps,$parents,$callStack)
    else
    if ($me/local-name(.) = "endEvent") then
      m:b2endEvent($rootName,$parentStep,$pname,$doc,$process,$me,$failureAction,$failureState,$pipelineMap,$stepMap,$pipelineSteps,$parents,$callStack)
    else
    if ($me/local-name(.) = "task") then
      m:b2task($rootName,$parentStep,$pname,$doc,$process,$me,$failureAction,$failureState,$pipelineMap,$stepMap,$pipelineSteps,$parents,$callStack)
    else
    if ($me/local-name(.) = "exclusiveGateway") then
      m:b2exclusiveGateway($rootName,$parentStep,$pname,$doc,$process,$me,$failureAction,$failureState,$pipelineMap,$stepMap,$pipelineSteps,$parents,$callStack)
    else
    if ($me/local-name(.) = "userTask") then
      m:b2userTask($rootName,$parentStep,$pname,$doc,$process,$me,$failureAction,$failureState,$pipelineMap,$stepMap,$pipelineSteps,$parents,$callStack)
    else
    if ($me/local-name(.) = "sendTask") then
      m:b2sendTask($rootName,$parentStep,$pname,$doc,$process,$me,$failureAction,$failureState,$pipelineMap,$stepMap,$pipelineSteps,$parents,$callStack)
    else
    if ($me/local-name(.) = "parallelGateway") then
      m:b2parallelGateway($rootName,$parentStep,$pname,$doc,$process,$me,$failureAction,$failureState,$pipelineMap,$stepMap,$pipelineSteps,$parents,$callStack)
    else
    if ($me/local-name(.) = "inclusiveGateway") then
      m:b2inclusiveGateway($rootName,$parentStep,$pname,$doc,$process,$me,$failureAction,$failureState,$pipelineMap,$stepMap,$pipelineSteps,$parents,$callStack)
    else
      xdmp:log("wfi:b2walkFrom: STEP NOT RECOGNISED!!!") (: TODO not supported warning, go to end of process placeholder from m:pipeline :)
    :)
    let $_ := m:map-append($pipelineSteps,$pname,$stepDef)
    let $_ := xdmp:log("b2WalkFrom received for '" || xs:string($me/local-name(.)) || "':-")
    let $_ := xdmp:log($stepDef)
    let $_ := map:put($stepMap,$nextStep (: Same as this as we've checked above - xs:string($me/@id):),fn:true()) (: must be after step is processed so each function can check it hasn't been executed before, if relevant (E.g. parallelGateway rendezvous) :)
    return ()
  else ()
};

declare function m:b2walkNext($rootName as xs:string,$parentStep as xs:string?,$doc as element(b2:definitions),
  $process as element(b2:process), $currentStep as element(),$failureAction,$failureState,$pipelineMap as map:map,
  $stepMap as map:map,$pipelineSteps as map:map,$parents as map:map,$callStack as map:map) as element()* {
  for $next in m:b2getNextSteps($process,$currentStep)
  let $_ := xdmp:log("wfi:b2walkNext: next step:-")
  let $_ := xdmp:log($next)
  return
    m:b2walkFrom($rootName,$parentStep,$doc,$process,xs:string($next/@id),$failureAction,$failureState,$pipelineMap,$stepMap,$pipelineSteps,$parents,$callStack)
};

(: STEP SPECIFIC FUNCTION CALLS FOR BPMN2 :)

declare function m:b2startEvent($rootName as xs:string,$parentStep as xs:string?,$pname as xs:string, $doc as element(b2:definitions),$process as element(b2:process),
    $state as element(b2:startEvent),$failureAction,$failureState,$pipelineMap as map:map,$stepMap as map:map,$pipelineSteps as map:map,$parents as map:map,$callStack as map:map) as element()* {
  let $_ := xdmp:log("In wfi:b2startEvent()")

      let $route := xs:string($state/b2:outgoing[1]) (: TODO support split here? :)
      let $rc :=
        if (fn:contains($route,":")) then
          fn:substring-after($route,":")
        else
          $route
      let $sf := $process/b2:sequenceFlow[./@id = $rc]
      return
      (
        p:state-transition(xs:anyURI("http://marklogic.com/states/"||$pname||"/"||xs:string($state/@id)),
          "",xs:anyURI("http://marklogic.com/states/"||$pname||"/"||xs:string($sf/@targetRef) ),
          $failureState,(),
          p:action("/workflowengine/actions/startEvent.xqy","BPMN2 start event: "||xs:string($state/@name),
              ()
            )
          ,
          ()
        )
        ,
        m:b2walkNext($rootName,$parentStep,$doc,$process,$state,$failureAction,$failureState,$pipelineMap,$stepMap,$pipelineSteps,$parents,$callStack)
      )
};

declare function m:b2endEvent($rootName as xs:string,$parentStep as xs:string?,$pname as xs:string, $doc as element(b2:definitions),$process as element(b2:process),
    $state as element(b2:endEvent),$failureAction,$failureState,$pipelineMap as map:map,$stepMap as map:map,$pipelineSteps as map:map,$parents as map:map,$callStack as map:map) as element()* {
  let $_ := xdmp:log("In wfi:b2endEvent()")
  return
    (
      p:state-transition(xs:anyURI("http://marklogic.com/states/"||$pname||"/"||xs:string($state/@id)),
        "",xs:anyURI("http://marklogic.com/states/"||$pname||"_end"),
        $failureState,(),
        p:action("/workflowengine/actions/endEvent.xqy","BPMN2 End Event: "||xs:string($state/@name),
            ()
          )
        ,
        ()
      )
      (:
      ,
      m:b2walkNext($rootName,$parentStep,$doc,$process,$state,$failureAction,$failureState,$pipelineMap,$stepMap,$pipelineSteps,$parents,$callStack)
      :) (: End event cannot have routes leaving it - TODO ensure message configuration does not look like a next step :)
    )
};

declare function m:b2task($rootName as xs:string,$parentStep as xs:string?,$pname as xs:string, $doc as element(b2:definitions),$process as element(b2:process),
    $state as element(b2:task),$failureAction,$failureState,$pipelineMap as map:map,$stepMap as map:map,$pipelineSteps as map:map,$parents as map:map,$callStack as map:map) as element()* {
  let $_ := xdmp:log("In wfi:b2task()")
      let $route := xs:string($state/b2:outgoing[1]) (: TODO support split here? :)
      let $rc :=
        if (fn:contains($route,":")) then
          fn:substring-after($route,":")
        else
          $route
      let $sf := $process/b2:sequenceFlow[./@id = $rc]
      return
      (
        p:state-transition(xs:anyURI("http://marklogic.com/states/"||$pname||"/"||xs:string($state/@id)),
          "",xs:anyURI("http://marklogic.com/states/"||$pname||"/"||xs:string($sf/@targetRef) ),
          $failureState,(),
          p:action("/workflowengine/actions/task.xqy","BPMN2 Task: "||xs:string($state/@name),
              ()
            )
          ,
          ()
        )
        ,
        m:b2walkNext($rootName,$parentStep,$doc,$process,$state,$failureAction,$failureState,$pipelineMap,$stepMap,$pipelineSteps,$parents,$callStack)
      )
};

declare function m:b2exclusiveGateway($rootName as xs:string,$parentStep as xs:string?,$pname as xs:string, $doc as element(b2:definitions),$process as element(b2:process),
    $state as element(b2:exclusiveGateway),$failureAction,$failureState,$pipelineMap as map:map,$stepMap as map:map,$pipelineSteps as map:map,$parents as map:map,$callStack as map:map) as element()* {
  let $_ := xdmp:log("In wfi:b2exclusiveGateway()")
  return
        (
          p:state-transition(xs:anyURI("http://marklogic.com/states/"||$pname||"/"||xs:string($state/@id)),
            "",(),
            $failureState,(),
            p:action("/workflowengine/actions/exclusiveGateway.xqy","BPMN2 Exclusive Gateway: "||xs:string($state/@name),
              <p:options xmlns:p="http:marklogic.com/cpf/pipelines">
                {
                  if (fn:not(fn:empty($state/@default))) then
                    let $sf := $process/b2:sequenceFlow[./@id = $state/@default]
                    return
                      <wf:default-route-state>{xs:anyURI("http://marklogic.com/states/"||$pname||"/"||xs:string($sf/@targetRef))}</wf:default-route-state>
                  else ()
                }
                {
                  for $route in $state/b2:outgoing
                  let $rc :=
                    if (fn:contains($route,":")) then
                      fn:substring-after($route,":")
                    else
                      $route
                  let $sf := $process/b2:sequenceFlow[./@id = $rc]
                  return
                    <wf:route>
                      <wf:state>{xs:anyURI("http://marklogic.com/states/"||$pname||"/"||xs:string($sf/@targetRef))}</wf:state>
                      <wf:name>{xs:string($sf/@name)}</wf:name>
                      <wf:condition language="{xs:string($sf/b2:conditionExpression[1]/@language)}">{$sf/b2:conditionExpression/text()}</wf:condition>
                    </wf:route>
                }
              </p:options>
            ),()
          )
          ,
          m:b2walkNext($rootName,$parentStep,$doc,$process,$state,$failureAction,$failureState,$pipelineMap,$stepMap,$pipelineSteps,$parents,$callStack)
        )
};

declare function m:b2userTask($rootName as xs:string,$parentStep as xs:string?,$pname as xs:string, $doc as element(b2:definitions),$process as element(b2:process),
    $state as element(b2:userTask),$failureAction,$failureState,$pipelineMap as map:map,$stepMap as map:map,$pipelineSteps as map:map,$parents as map:map,$callStack as map:map) as element()* {
  let $_ := xdmp:log("In wfi:b2userTask()")
      let $type :=
        if ($state/b2:resourceRole/@name = "Assignee") then
          "user"
        else if ($state/b2:resourceRole/@name = "Queue") then
          "queue"
        else if ($state/b2:resourceRole/@name = "Role") then
          "role"
        else if (fn:not(fn:empty($state/b2:humanPerformer))) then
          "dynamicUser"
        else
          "unknown"
      let $userResource := ($state/b2:resourceRole[@name = "Assignee"])[1]/b2:resourceRef/text()
      let $user := xs:string($doc/b2:resource[@id = $userResource]/@name)
      let $queueResource := ($state/b2:resourceRole[@name = "Queue"])[1]/b2:resourceRef/text()
      let $queue := xs:string($doc/b2:resource[@id = $queueResource]/@name)
      let $roleResource := ($state/b2:resourceRole[@name = "Role"])[1]/b2:resourceRef/text()
      let $role := xs:string($doc/b2:resource[@id = $roleResource]/@name)
      let $dynamicUser := xs:string($state/b2:humanPerformer/b2:resourceAssignmentExpression/b2:formalExpression)

      let $route := xs:string($state/b2:outgoing[1]) (: TODO support split here? :)
      let $rc :=
        if (fn:contains($route,":")) then
          fn:substring-after($route,":")
        else
          $route
      let $sf := $process/b2:sequenceFlow[./@id = $rc]
      let $_ := xdmp:log("user task: " || xs:string($state/@id) || " out route: " || $route || ", target ref: " || xs:string($sf/@targetRef))
      return
        (p:state-transition(xs:anyURI("http://marklogic.com/states/"||$pname||"/"||xs:string($state/@id)),
          "",(),
          $failureState,(), () (: empty default action :)
          ,
          ( (: execute set :)
            p:execute(
              p:condition("/workflowengine/conditions/hasEntered.xqy","Check if just entered",())
              ,
              p:action("/workflowengine/actions/userTask.xqy","BPMN2 User Task: "||xs:string($state/@name),

                <p:options xmlns:p="http:marklogic.com/cpf/pipelines">
                  <wf:type>{$type}</wf:type>
                  {
                    if (fn:not(fn:empty($user))) then <wf:assignee>{$user}</wf:assignee> else ()
                  }
                  {
                    if (fn:not(fn:empty($queue))) then <wf:queue>{$queue}</wf:queue> else ()
                  }
                  {
                    if (fn:not(fn:empty($role))) then <wf:role>{$role}</wf:role> else ()
                  }
                  {
                    if (fn:not(fn:empty($dynamicUser))) then <wf:dynamicUser>{$dynamicUser}</wf:dynamicUser> else ()
                  }
                  <wf:state>{xs:anyURI("http://marklogic.com/states/"||$pname||"/"||xs:string($state/@id)||"__complete")}</wf:state>
                </p:options>
              ) (: p action :)
              ,"Apply set up user task action on entry"
            ) (: p:execute :)

            (:
            ,
            p:execute(
              p:condition("/workflowengine/conditions/isComplete.xqy","Check if complete",())
              ,
              p:action("/workflowengine/actions/genericComplete.xqy",
                "Wait for user completion: "||xs:string($state/@name),
                <p:options xmlns:p="http:marklogic.com/cpf/pipelines">
                  <wf:state>{xs:anyURI("http://marklogic.com/states/"||$pname||"/"||xs:string($sf/@targetRef))}</wf:state>
                </p:options>
              ),
              "Apply default complete action"
            ) (: p execute :)
            :)


          ) (: execute set :)
        ) (: state transition :)
        ,
        (:
        p:state-transition(xs:anyURI("http://marklogic.com/states/"||$pname||"/"||xs:string($state/@id)||"__inprogress"),
          "",(),
          $failureState,(),
          () (: empty default action :)
          ,
          (


          ) (: execute set :)
        )
        ,
        :)
        p:state-transition(xs:anyURI("http://marklogic.com/states/"||$pname||"/"||xs:string($state/@id)||"__complete"),
          "",xs:anyURI("http://marklogic.com/states/"||$pname||"/"||xs:string($sf/@targetRef)),
          $failureState,(),
          p:action("/workflowengine/actions/genericComplete.xqy",
            "User completion occurred: "||xs:string($state/@name),() (: options :)
          ) (: empty default action :)
          ,
          (


          ) (: execute set :)
        )

        ,
        m:b2walkNext($rootName,$parentStep,$doc,$process,$state,$failureAction,$failureState,$pipelineMap,$stepMap,$pipelineSteps,$parents,$callStack)

      ) (: state transition set :)


};


declare function m:b2sendTask($rootName as xs:string,$parentStep as xs:string?,$pname as xs:string, $doc as element(b2:definitions),$process as element(b2:process),
    $state as element(b2:sendTask),$failureAction,$failureState,$pipelineMap as map:map,$stepMap as map:map,$pipelineSteps as map:map,$parents as map:map,$callStack as map:map) as element()* {
  let $_ := xdmp:log("In wfi:b2sendTask()")
      let $messageText := xs:string($doc/b2:message[@id = $state/@messageRef]/@name)
      (:
      let $item := $doc/b2:itemDefinition[@id = $message/@itemRef]
      let $structureRef := xs:string($item/@structureRef)

      let $operation := $doc/b2:interface/b2:operation[@id = $state/@operationRef]
      :)

      let $route := xs:string($state/b2:outgoing[1]) (: TODO support split here? :)
      let $rc :=
        if (fn:contains($route,":")) then
          fn:substring-after($route,":")
        else
          $route
      let $sf := $process/b2:sequenceFlow[./@id = $rc]
      return
        (
          p:state-transition(xs:anyURI("http://marklogic.com/states/"||$pname||"/"||xs:string($state/@id)),
            "",xs:anyURI("http://marklogic.com/states/"||$pname||"/"||xs:string($sf/@targetRef)),
            $failureState,(),
            p:action("/workflowengine/actions/sendTask.xqy","BPMN2 Send Task: "||xs:string($state/@name),
              <options xmlns="/workflowengine/actions/sendTask.xqy">
                <wf:message>{$messageText}</wf:message>
              </options>
            ),()
          )
          ,
          m:b2walkNext($rootName,$parentStep,$doc,$process,$state,$failureAction,$failureState,$pipelineMap,$stepMap,$pipelineSteps,$parents,$callStack)
        )
};

(: Create the DIVERGING state transition :)
declare function m:b2gatewayDiverging($gatewayType as xs:string,$myname as xs:string,$pname as xs:string,$state as element(),$failureState,$process as element(b2:process)) as item() {
  p:state-transition(xs:anyURI($myname),
  "",xs:anyURI("http://marklogic.com/states/"||$pname||"/"||xs:string($state/@id)||"__rv"),
  $failureState,(),
  p:action("/workflowengine/actions/fork.xqy","BPMN2 " || $gatewayType || " Gateway Fork: "||xs:string($state/@name),
    <p:options xmlns:p="http:marklogic.com/cpf/pipelines">
      <wf:branch-definitions>
        {
          (: We can go straight to the next steps, as there are ZERO conditions on our routes, unlike other gateways :)

            for $route in $state/b2:outgoing
            let $txt := xs:string($route)
            let $rc :=
              if (fn:contains($txt,":")) then
                fn:substring-after($txt,":")
              else
                $txt
            let $sf := $process/b2:sequenceFlow[./@id = $rc]
            let $nextState := $process/element()[./@id = xs:string($sf/@targetRef)]
            (: NB MUST do the above not call the func, because the conditions are on the outgoing routes :)
          (: for $nextState in m:b2getNextSteps($process,$state) :)
          return
            <wf:branch-definition>
              <wf:pipeline>{$pname}</wf:pipeline>
              <wf:branch>{$pname || "/" || xs:string($nextState/@id)}</wf:branch>
              {
                if ($gatewayType = "INCLUSIVE") then
                  (: Add in branch condition :)
                  if ($sf/@id = $state/@default) then
                    <wf:default>true</wf:default>
                  else
                    <wf:condition language="{xs:string($sf/b2:conditionExpression[1]/@language)}">{$sf/b2:conditionExpression/text()}</wf:condition>
                else ()
              }
            </wf:branch-definition>
        }
        {

          (: No need - tagged branch as default above :)
          (:
          if ($gatewayType = "INCLUSIVE") then
            (: Add in branch definition for DEFAULT route :)
          else ()
          :)
        }
        <wf:fork-method>{
          if ($gatewayType = "PARALLEL") then
            "ALL"
          else if ($gatewayType = "INCLUSIVE") then
            "CONDITIONAL"
          else
            "UNKNOWN"
        }</wf:fork-method>
        <wf:rendezvous-method>ALL</wf:rendezvous-method>
      </wf:branch-definitions>
    </p:options>
  ),()
)
};

declare function m:b2gatewayConvergingParent($gatewayType as xs:string,$stepMap as map:map,$state as element(),
  $callStack as map:map,$pipelineSteps as map:map,$failureState,$process as element(b2:process)) as empty-sequence() {

    if (fn:empty(map:get($stepMap,xs:string($state/@id)))) then
    (:
      Get previous stack parent WHERE frame end state id is blank
      ALSO if you encounter this state's ID, then it has been processed before, so do not continue processing children
    :)
      let $parentFrame := stack:peek($callStack)
      let $_ := xdmp:log("PARENT FRAME:-")
      let $_ := xdmp:log($parentFrame)
      let $_ := xdmp:log("PARENT FRAME stateid:-")
      let $_ := xdmp:log($parentFrame/stateId)
      return


        (: GENERATE RENDEZVOUS STATE NOW :)
        m:map-append($pipelineSteps,xs:string($parentFrame/pname),
          (
          (: peek gives PREVIOUS level on call stack, not currently level :)
          p:state-transition(xs:anyURI("http://marklogic.com/states/"||xs:string($parentFrame/pname)||"/"||xs:string($parentFrame/stateId)||"__rv"), (: NOTE this name reflects the owning PARENT process :)
            "",(), (: TODO send to next state in flow once completed :)
            $failureState,(),
            () (: empty default action :)
            ,
            (: execute set :)
            p:execute(
              p:condition("/workflowengine/conditions/hasRendezvoused.xqy","Check if child processes are finished",())
              ,
              p:action("/workflowengine/actions/genericComplete.xqy","BPMN2 Parallel Gateway Rendezvous: "||xs:string($state/@name),
                <p:options xmlns:p="http:marklogic.com/cpf/pipelines">
                  <wf:state>{xs:string(m:b2getNextSteps($process,$state)[1]/@id)}</wf:state>
                </p:options>
              ) (: p action :)
              ,"Check if child processes are complete on entry"
            )
          )
          (: TODO generate a state that moves from our state id (RV converging) to the next step in sequence flow :)
          ,()
          )
        )

    else ()
};

declare function m:b2gatewayConvergingEnd($gatewayType as xs:string,$pname as xs:string,$state as element(),
  $failureState) as item() {
  (
    xdmp:log("wfi:b2gatewayConvergingEnd(): entered method")
    ,
        (: return a placeholder with this state's name in the current process flow too, transitioning to the __end state for sub process :)
        p:state-transition(xs:anyURI("http://marklogic.com/states/"||$pname||"/"||xs:string($state/@id)),
          "",xs:anyURI("http://marklogic.com/states/"||$pname||"__end" ),
          $failureState,(),

          p:action("/workflowengine/actions/task.xqy","BPMN2 " || $gatewayType || " Gateway Placeholder: "||xs:string($state/@id),
            <p:options xmlns:p="http:marklogic.com/cpf/pipelines">
            </p:options>
          )
          ,
          ()
        )
  )
};

declare function m:b2gatewayForkRV($gatewayType as xs:string,$rootName as xs:string,$parentStep as xs:string?,$pname as xs:string, $doc as element(b2:definitions),$process as element(b2:process),
  $state as element(),$failureAction,$failureState,$pipelineMap as map:map,$stepMap as map:map,$pipelineSteps as map:map,$parents as map:map,$callStack as map:map) as element()* {

  let $_ := xdmp:log("m:b2gatewayForkRV(): entered function")
        (:
         : TODO ensure the diverging state has it's next step name in the cpf:options configuration for after rendezvous
         :)
        let $myname := "http://marklogic.com/states/"||$pname||"/"||xs:string($state/@id)
        let $_ := xdmp:log("This " || $gatewayType || " gateway: " || $myname || " has a direction of: " || xs:string($state/@gatewayDirection))
        return
          if (xs:string($state/@gatewayDirection) = "Diverging") then
          (
            m:b2gatewayDiverging($gatewayType,$myname,$pname,$state,$failureState,$process)
            ,


            (: NOW LOOP THROUGH OUTGOING AND GENERATE A PIPELINE PER ROUTE :)
            for $nextState in m:b2getNextSteps($process,$state)
            let $_ := xdmp:log("wfi:b2getNextSteps: Generating sub pipeline for " || xs:string($state/@id) || " going to next state: " || xs:string($nextState/@id))
            let $subProcId := m:b2subPipeline($rootName,xs:string($state/@id),$doc,$process,$myname,$state,$pname,$nextState,$failureAction,$failureState,$pipelineMap,$stepMap,$pipelineSteps,$parents,$callStack)
            return ()
          )



        else if (xs:string($state/@gatewayDirection) = "Converging") then
        (
          (:
           : Remove ourselves from the step map to ensure the rendezvous is processed for each fork
           :)
          let $_ := xdmp:log("MAP CHECK FOR CURRENT STATE RV CONVERGING CREATION:-")
          let $_ := xdmp:log(map:get($stepMap,xs:string($state/@id)))
          let $continueProcessing :=
            m:b2gatewayConvergingParent($gatewayType,$stepMap,$state,$callStack,$pipelineSteps,$failureState,$process)


          return
          (:
            Don't think we need the below - done by walkNext

          (: return a placeholder with this state's name in the current process flow too, transitioning to the __end state for sub process :)
          p:state-transition(xs:anyURI($myname), (: NOTE this name reflects the owning PARENT process :)
            "",xs:anyURI("http://marklogic.com/states/"||$pname||"__end" ),
            $failureState,(),
            (:
            p:action("/workflowengine/actions/task.xqy","BPMN2 Parallel Gateway Placeholder: "||xs:string($state/@name),
              <p:options xmlns:p="http:marklogic.com/cpf/pipelines">
              </p:options>
            )
            :)
            (),()
          ),

          :)
          (
            xdmp:log("About to call wfi:b2gatewayConvergingEnd()")
            ,
            m:b2gatewayConvergingEnd($gatewayType,$pname,$state,$failureState)
            ,
            if (fn:true() (: $continueProcessing:) ) then

            let $parentFrame := stack:peek($callStack)
            let $parentPname := $parentFrame/pname

            let $_ := stack:pop($callStack)

            (: NOW continue along flow as normal in PARENTS context:)
            let $_ := xdmp:log("m:b2gatewayForkRV(): About to walk next after end of CHILD rv. callstack top now:-")
            let $_ := xdmp:log(stack:peek($callStack))
            return
              m:b2walkNext($rootName,(:fn:substring-after(map:get($parents,$pname),"/"):)
              (: Horrible, horrible hack due to recursion and some unidentifiable function nesting rootName within parentName :)

                if (() = fn:substring-after(fn:substring-after(xs:string($parentPname),"/"),"/") ) then
                  xs:string($parentPname)
                else
                  fn:substring-after(xs:string($parentPname),"/")



                (: )$parentPname :)
                ,$doc,$process,$state,$failureAction,$failureState,$pipelineMap,$stepMap,
                $pipelineSteps,$parents,$callStack)
            else () (:continue processing if :)
          )
        ) (: end if :)



        else xdmp:log("UNKNOWN DIRECTION: " || xs:string($state/@gatewayDirection))
};

declare function m:b2parallelGateway($rootName as xs:string,$parentStep as xs:string?,$pname as xs:string, $doc as element(b2:definitions),$process as element(b2:process),
    $state as element(b2:parallelGateway),$failureAction,$failureState,$pipelineMap as map:map,$stepMap as map:map,$pipelineSteps as map:map,$parents as map:map,$callStack as map:map) as element()* {
  let $_ := xdmp:log("In wfi:b2parallelGateway()")
  return m:b2gatewayForkRV("PARALLEL",$rootName,$parentStep,$pname,$doc,$process,$state,$failureAction,$failureState,$pipelineMap,$stepMap,$pipelineSteps,$parents,$callStack)
};

declare function m:b2inclusiveGateway($rootName as xs:string,$parentStep as xs:string?,$pname as xs:string, $doc as element(b2:definitions),$process as element(b2:process),
    $state as element(b2:inclusiveGateway),$failureAction,$failureState,$pipelineMap as map:map,$stepMap as map:map,$pipelineSteps as map:map,$parents as map:map,$callStack as map:map) as element()* {
  let $_ := xdmp:log("In wfi:b2inclusiveGateway()")
  return m:b2gatewayForkRV("INCLUSIVE",$rootName,$parentStep,$pname,$doc,$process,$state,$failureAction,$failureState,$pipelineMap,$stepMap,$pipelineSteps,$parents,$callStack)
};

(: END BPMN2 CUSTOM TASK FUNCTIONS :)

declare function m:b2getNextSteps($process as element(b2:process),$state as element()) as element()* {
  for $route in $state/b2:outgoing
  let $txt := xs:string($route)
  let $rc :=
    if (fn:contains($txt,":")) then
      fn:substring-after($txt,":")
    else
      $txt
  let $sf := $process/b2:sequenceFlow[./@id = $rc]
  return $process/element()[./@id = xs:string($sf/@targetRef)]
};
