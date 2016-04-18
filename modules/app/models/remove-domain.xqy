xquery version "1.0-ml";

declare namespace m="http://marklogic.com/alerts";

import module namespace dom = "http://marklogic.com/cpf/domains" at "/MarkLogic/cpf/domains.xqy";

declare variable $m:processmodeluri as xs:string external;

dom:remove($m:processmodeluri)