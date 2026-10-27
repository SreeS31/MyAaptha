import {test,expect} from '@playwright/test';
import {mergeMessagePage} from '../app/lib/message-pages';
test('older pages and refreshed records preserve history without duplicates',()=>{
 const current=[{id:51,text:'old'},{id:52,text:'keep'}];
 const older=mergeMessagePage(current,[{id:50,text:'earlier'}]);
 expect(mergeMessagePage(older,[{id:51,text:'edited'},{id:53,text:'new'}])).toEqual([{id:50,text:'earlier'},{id:51,text:'edited'},{id:52,text:'keep'},{id:53,text:'new'}]);
});
test('a full disjoint new page resets the cursor window so gaps remain accessible',()=>{
 const page=Array.from({length:50},(_,i)=>({id:100+i}));
 expect(mergeMessagePage([{id:1}],page)).toEqual(page);
});
test('an exhausted older cursor does not erase the current history',()=>{
 expect(mergeMessagePage([{id:1}],[])).toEqual([{id:1}]);
});
