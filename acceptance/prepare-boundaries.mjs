import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {writeFileSync} from 'node:fs';

const run=(...args)=>execFileSync('calcit',args,{encoding:'utf8',maxBuffer:8*1024*1024,stdio:['ignore','pipe','pipe']});
const query=(...args)=>JSON.parse(run('query',...args,'--format','json'));
const at=(node,path)=>path.reduce((part,index)=>part[index],node);
const login=query('def','app.comp.login/on-submit').data;
const connection=query('def','app.sync.client/connection-url').data;
assert.deepEqual(at(login.code,[3,3,2,1,0,1]),['unsafe-coerce','js/localStorage',"'js-ffi.browser/StorageHost"]);
assert.deepEqual(at(connection.code,[3,1,1,1]),['unsafe-coerce',['url-parse',['location',':href'],'true'],"'app.sync.client/ParsedConnectionHost"]);
const replace=(target,path,code)=>['tree','replace',target,'--path',path,'--input-format','json-ast','--code',JSON.stringify(code)];
const read=(name)=>['contract/object-field','|connection query','query','|'+name];
const optional=(name,fallback)=>['match',['js-nullish->option',read(name)],
  [[':none'],fallback],[[':some','value'],['contract/expect-string','|connection '+name,'value']]];
const operations=[
  ['edit','add-import','app.comp.login','--input-format','json-ast','--code',JSON.stringify(['js-ffi.browser',':as','browser'])],
  replace('app.comp.login/on-submit','3.3.2.1.0.1',['browser/window-local-storage']),
  ['edit','add-import','app.sync.client','--input-format','json-ast','--code',JSON.stringify(['js-ffi.contract',':as','contract'])],
  replace('app.sync.client/connection-url','3.1.1.1',['url-parse',['location',':href'],'true']),
  replace('app.sync.client/connection-url','3.1.2.1',['contract/object-field','|parsed connection URL','parsed','|query']),
  replace('app.sync.client/connection-url','3.1.3.1',optional('host',['location',':hostname'])),
  replace('app.sync.client/connection-url','3.1.4.1',optional('port',['str',['.unwrap',['get','config/site',':port']]])),
  ['edit','rm-def','app.sync.client/ParsedConnectionHost'],
  ['edit','rm-def','app.sync.client/ConnectionQueryHost'],
  ['edit','schema','app.client/main!','--input-format','cirru','--code',"quote $ :: 'Fn $ {} (:args $ []) (:return 'Unit) (:features $ #{} :js-ffi)"],
  ['edit','schema','app.config/dev?','--input-format','json-ast','--code',JSON.stringify("'Bool")],
];
writeFileSync('acceptance/operations.json',JSON.stringify(operations,null,2));
writeFileSync('acceptance/usages-before.txt',run('query','usages','app.sync.client/ParsedConnectionHost'));
writeFileSync('acceptance/connection-before.json',JSON.stringify(connection,null,2));
const args=['edit','transaction','--file','acceptance/operations.json','--format','json'];
const preview=JSON.parse(run(...args,'--dry-run'));
writeFileSync('acceptance/preview.json',JSON.stringify(preview,null,2));
writeFileSync('acceptance/applied.json',run(...args,'--expect-revision',preview.scoped_revision));
for(const target of ['app.comp.login/on-submit','app.sync.client/connection-url','app.client/main!','app.config/dev?']){
  writeFileSync('acceptance/'+target.replaceAll('/','-').replaceAll('?','q').replaceAll('!','bang')+'.json',JSON.stringify(query('def',target),null,2));
}
writeFileSync('acceptance/program-diff.json',run('analyze','program-diff','HEAD','--format','json'));
for(const name of ['ParsedConnectionHost','ConnectionQueryHost']){
  const result=query('search',name);
  assert.equal(result.data.summary.matches,0,`${name}: references remain`);
}
