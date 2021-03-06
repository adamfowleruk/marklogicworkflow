(:
Copyright 2012 MarkLogic Corporation

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
:)
xquery version "1.0-ml";

module namespace c = "http://marklogic.com/test-config";

(: configured at deploy time by Roxy deployer :)
declare variable $c:USER := "%%mlUsername%%";
declare variable $c:PASSWORD := "%%mlPassword%%";
declare variable $c:RESTHOST := "localhost";
declare variable $c:RESTPORT := "%%mlTestRestPort%%";
declare variable $LOCAL-TEST-DATA-DIR := "/raw/bpmn/";
declare variable $SLEEP-FOR-ASYNC := 5; (: Sleep period required, in seconds, for async tasks :)

declare function local-uri-for-test-file($test-file-name as xs:string){
	$LOCAL-TEST-DATA-DIR||$test-file-name
};

declare function test-sleep(){
	xdmp:sleep($SLEEP-FOR-ASYNC * 1000)
};
