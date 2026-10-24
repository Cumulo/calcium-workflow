import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {readFileSync,writeFileSync} from 'node:fs';
const run=(...a)=>execFileSync('calcit',a,{encoding:'utf8',maxBuffer:32e6,stdio:['ignore','pipe','pipe']});
function norm(v){if(Array.isArray(v))return v.map(norm);if(v&&typeof v==='object'){const x=Object.fromEntries(Object.entries(v).map(([k,a])=>[k,norm(a)]));if(Object.keys(x).length===1&&Array.isArray(x.__edn_set))x.__edn_set.sort((a,b)=>JSON.stringify(a).localeCompare(JSON.stringify(b)));return x;}return v;}
const q=(...a)=>norm(JSON.parse(run('query',...a,'--format','json')).data);
assert.equal(run('-v').trim(),'0.30.1');writeFileSync('acceptance/agent-contract.txt',run('docs','agents','--contract'));
assert.equal(execFileSync('git',['hash-object','calcit.cirru'],{encoding:'utf8'}).trim(),'409d8180508771f0fa427463a2c753f095056085');
const before=norm(JSON.parse(readFileSync('reviewed.json','utf8'))),expected=structuredClone(before);
const config=q('config'),namespaces=q('ns').namespaces.map(ns=>q('ns',ns));
const evidence=JSON.parse(readFileSync('reviewed-types.json','utf8'));
assert.equal(evidence.length,32);
const styles=['global','fullscreen','column-dispersive'].map(n=>q('def',`respo-ui.core/${n}`));
for(const d of styles){assert.equal(d.schema[0],'::');assert.equal(d.schema[1],"'Map");}
writeFileSync('acceptance/reviewed-ui-styles.json',JSON.stringify(styles,null,2));
const aliases={count:'.len',merge:'.merge',foldl:'.foldl'},counts={},ops=[];
let tests=0,proven=0,manual=0;
function walk(x,path,id,region){
  if(!Array.isArray(x)||['quote','quasiquote',';','comment','defmacro'].includes(x[0]))return;
  if(Object.hasOwn(aliases,x[0])){
    const old=x[0],method=aliases[old];
    assert.ok(old==='count'?x.length===2:old==='merge'?x.length>=3:x.length===4);
    if(region==='code'){
      const proof=evidence.find(e=>e.id===id&&JSON.stringify(e.path)===JSON.stringify(path));
      assert.ok(proof);assert.deepEqual(proof.tree,x);assert.equal(proof.status,0);
      const data=proof.evidence.data,diags=proof.evidence.diagnostics;
      const resolved=data.static_methods?.find(m=>m.name===method);
      if(old==='merge'){
        if(id==='app.comp.container/comp-offline'){
          assert.equal(data.inferred_type,null);assert.equal(diags.length,1);assert.equal(diags[0].code,'W_TYPE_AT_UNRESOLVED');
          assert.deepEqual(x.slice(1,4),['ui/global','ui/fullscreen','ui/column-dispersive']);
        }else{assert.equal(data.inferred_type,":: 'Map 'Tag 'Dynamic");assert.deepEqual(diags,[]);assert.equal(resolved.status,'open');assert.equal(resolved.definition,'calcit.core/merge');}
        manual++;
      }else if(old==='foldl'&&['app.schema/decode-messages','app.schema/decode-sessions','app.schema/decode-users'].includes(id)){
        assert.equal(data.inferred_type,":: 'List 'List");assert.deepEqual(diags,[]);assert.equal(resolved.status,'open');assert.equal(resolved.definition,'calcit.core/foldl');assert.deepEqual(x[1],['&map:to-list','data']);manual++;
      }else if(id==='app.sync.server/collect-partitions!'){
        assert.equal(resolved.status,'proven');assert.equal(resolved.definition,'calcit.core/foldl');assert.equal(diags.length,1);assert.equal(diags[0].code,'W_TYPE_AT_EXPECTED_MISMATCH');
        assert.deepEqual(x[1],['map-entries','@*partition-progress']);manual++;
      }else{
        assert.deepEqual(diags,[]);assert.equal(resolved.status,'proven');
        if(old==='count'){assert.ok(['calcit.core/&list:count','calcit.core/&map:count','calcit.core/&set:count'].includes(resolved.definition));assert.deepEqual(resolved.call_types,{parameters:[],rest:null,returns:"'Number"});}
        else assert.equal(resolved.definition,'calcit.core/foldl');proven++;
      }
      const p='@'+[...path,0].join('.');assert.equal(JSON.parse(run('tree','show',id,'--path',p,'--format','json')).tree,old);
      ops.push(['tree','replace',id,'--path',p,'--input-format','json-ast','--code',JSON.stringify(method),'--expect','quote '+old]);
    }
    counts[region+':'+old]=(counts[region+':'+old]||0)+1;x[0]=method;
  }
  x.forEach((v,i)=>walk(v,[...path,i],id,region));
}
for(const d of expected){
  assert.deepEqual(q('def',d.id),before.find(x=>x.id===d.id));
  walk(d.code,[],d.id,'code');
  for(const t of d.tests){const old=JSON.stringify(t.code);walk(t.code,[],d.id,'test');if(old!==JSON.stringify(t.code)){const op=['edit','add-test',d.id,t.name,'--overwrite','--input-format','json-ast','--code',JSON.stringify(t.code)];if(t.tags.length)op.push('--tags',t.tags.join(','));ops.push(op);tests++;}}
}
assert.deepEqual(counts,{'code:merge':10,'code:count':13,'test:count':9,'code:foldl':9,'test:foldl':1});
assert.equal(tests,5);assert.equal(ops.length,37);
assert.equal(proven,18);assert.equal(manual,14);
writeFileSync('acceptance/operations.json',JSON.stringify(ops,null,2));
const args=['edit','transaction','--file','acceptance/operations.json','--format','json'];
const preview=JSON.parse(run(...args,'--dry-run'));assert.ok(preview.scoped_revision);
writeFileSync('acceptance/transaction-preview.json',JSON.stringify(preview,null,2));
writeFileSync('acceptance/transaction-applied.json',run(...args,'--expect-revision',preview.scoped_revision));
const actual=[];for(const ns of namespaces){const names=run('query','defs',ns.namespace).split('\n').filter(x=>/^  \S/.test(x)).map(x=>x.trim().split(' ')[0]);assert.equal(names.length,ns.definition_count);for(const name of names)actual.push(q('def',`${ns.namespace}/${name}`));}
assert.deepEqual(actual,expected);assert.deepEqual(q('config'),config);assert.deepEqual(q('ns').namespaces.map(ns=>q('ns',ns)),namespaces);
writeFileSync('acceptance/after.json',JSON.stringify(actual,null,2));
writeFileSync('acceptance/summary.json',JSON.stringify({definitions:324,originalTests:99,counts,proven,manual,namedTestsUpdated:tests,operations:37,preserved:'all operands/order/reducers/defaults/metadata/schemas/ns/config/FFI/HUD/storage/protocol/tests names/tags/assertions'},null,2));
writeFileSync('acceptance/snapshot-after-blob.txt',execFileSync('git',['hash-object','calcit.cirru'],{encoding:'utf8'}));
