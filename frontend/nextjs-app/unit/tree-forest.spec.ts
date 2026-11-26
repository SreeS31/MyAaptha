import {test,expect} from '@playwright/test';
import {forestLayout} from '../app/lib/tree-forest';
import type {ReviewedTree,TreeCard} from '../app/lib/reviewed-trees';
test('expanded thirty-person clusters have unique positions and remain connected to their groups',()=>{
 const cards:TreeCard[]=Array.from({length:7},(_,i)=>({id:i+1,key:null,name:'Tree '+i,reason:'',confidence:'',count:30,preview:[],version:1}));
 const tree:ReviewedTree={id:1,sourceKey:null,name:'Tree 0',reason:'',confidence:'',version:1,nodes:Array.from({length:30},(_,i)=>({key:'n'+i,name:'Person '+i,relation:'Member',contactId:null,parentKey:i===1?'n0':null}))};
 const graph=forestLayout(cards,{1:tree},{});expect(graph.groups).toHaveLength(7);expect(graph.groups[0].people).toHaveLength(30);expect(graph.groups[0].people[0].hasChildren).toBe(true);expect(graph.groups.slice(1).every(g=>g.people.length===0)).toBe(true);
 const people=graph.groups[0].people;for(let i=0;i<people.length;i++)for(let j=i+1;j<people.length;j++)expect(Math.abs(people[i].x-people[j].x)>=150||Math.abs(people[i].y-people[j].y)>=60).toBe(true);
});
test('deep trees are bounded without recursion and ancestors precede their children',()=>{
 const tree:ReviewedTree={id:1,sourceKey:null,name:'Chain',reason:'',confidence:'',version:1,nodes:Array.from({length:5000},(_,i)=>({key:'n'+i,name:'Person '+i,relation:'Member',contactId:null,parentKey:i?'n'+(i-1):null}))};
 const card:TreeCard={id:1,key:null,name:'Chain',reason:'',confidence:'',count:5000,preview:[],version:1};const graph=forestLayout([card],{1:tree},{});expect(graph.groups[0].people).toHaveLength(80);expect(graph.groups[0].total).toBe(5000);expect(graph.groups[0].people[79].node.parentKey).toBe('n78');
});
