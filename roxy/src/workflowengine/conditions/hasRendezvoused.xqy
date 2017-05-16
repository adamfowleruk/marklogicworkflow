xquery version "1.0-ml";
(: Checks to see if this parent process has all its children in a state, for this specific configuration, that means
   all child processes have rendezvoused, and if so, continues to the next state :)

import module namespace cpf = "http://marklogic.com/cpf" at "/MarkLogic/cpf/cpf.xqy";
import module namespace wfu="http://marklogic.com/workflow-util" at "/app/models/workflow-util.xqy";

declare namespace wf="http://marklogic.com/workflow";
declare namespace prop = "http://marklogic.com/xdmp/property";

declare variable $cpf:document-uri as xs:string external;
declare variable $cpf:transition as node() external;
declare variable $cpf:options as element() external;


let $activeFork := xdmp:document-properties($cpf:document-uri)/prop:properties/wf:branches[./wf:status = "INPROGRESS"]

(: Check RV method :)
let $outcome :=
  if ($activeFork/wf:rendezvous-method = "ALL") then
    (: Ensure all forks' status are COMPLETE to return true :)
    fn:empty($activeFork/wf:branch-status[./wf:status = "INPROGRESS"])
  else
    fn:false() (: TODO implement AllTolerant and One methods too :)

return (
   xdmp:log( fn:concat("MarkLogic Workflow hasRendezvoused condition result=", fn:string($outcome), " for ", $cpf:document-uri) ),
   $outcome
)

(: End of hasRendezvoused.xqy :)
