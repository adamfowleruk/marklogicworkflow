xquery version "1.0-ml";

import module namespace test-config = "http://marklogic.com/roxy/test-config" at "/test/test-config.xqy";
import module namespace test = "http://marklogic.com/roxy/test-helper" at "/test/test-helper.xqy";
import module namespace test-constants = "http://marklogic.com/workflow/test-constants/inclusive-gateway" at "lib/constants.xqy";

declare namespace wf = "http://marklogic.com/workflow";
	
for $test-file in $test-constants:TEST-FILES
let $target-uri := test-config:local-uri-for-test-file($test-file)
return
test:load-test-file($test-file, xdmp:database(), $target-uri)
,
(: As this test is about process model metadata, make sure we don't have any unwanted model metadata being used :)
/wf:process-model-metadata ! xdmp:document-delete(fn:base-uri(.))