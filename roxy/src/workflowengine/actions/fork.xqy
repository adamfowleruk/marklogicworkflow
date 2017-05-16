xquery version "1.0-ml";

import module namespace cpf = "http://marklogic.com/cpf" at "/MarkLogic/cpf/cpf.xqy";
import module namespace wfu="http://marklogic.com/workflow-util" at "/app/models/workflow-util.xqy";

declare namespace wf="http://marklogic.com/workflow";
declare namespace prop = "http://marklogic.com/xdmp/property";

declare variable $cpf:document-uri as xs:string external;
declare variable $cpf:transition as node() external;
declare variable $cpf:options as element() external;

(: Just call wfu:fork with $cpf:options/wf:branches spec :)
try {
  wfu:fork($cpf:document-uri,$cpf:options/wf:branches)
} catch ($e) {
  wfu:failure( $cpf:document-uri, $cpf:transition, $e, () )
}
