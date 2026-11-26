import type {ReviewedTree,TreeCard,TreeNode} from './reviewed-trees';
export type ForestPerson={node:TreeNode;treeId:number;x:number;y:number;hasChildren:boolean};
export type ForestGroup={card:TreeCard;x:number;y:number;radius:number;people:ForestPerson[];total:number};
export function forestLayout(cards:TreeCard[],trees:Record<number,ReviewedTree|undefined>,limits:Record<number,number>){
 const groups=cards.map(card=>{
  const nodes=trees[card.id!]?.nodes||[],byParent=new Map<string|null,TreeNode[]>(),seen=new Set<string>(),ordered:TreeNode[]=[];
  nodes.forEach(node=>{const list=byParent.get(node.parentKey)||[];list.push(node);byParent.set(node.parentKey,list);});
  const stack=[...(byParent.get(null)||[])].reverse();
  while(stack.length){const node=stack.pop()!;if(seen.has(node.key))continue;seen.add(node.key);ordered.push(node);stack.push(...[...(byParent.get(node.key)||[])].reverse());}
  nodes.forEach(node=>{if(!seen.has(node.key))ordered.push(node);});
  const shown=ordered.slice(0,limits[card.id!]||80),people:ForestPerson[]=[];let offset=0,ring=0,radius=0;
  while(offset<shown.length){radius=180+ring*180;const count=Math.min(shown.length-offset,Math.floor(2*Math.PI*radius/180));for(let i=0;i<count;i++){const angle=-Math.PI/2+i*2*Math.PI/count;const node=shown[offset+i];people.push({node,treeId:card.id!,x:Math.cos(angle)*radius,y:Math.sin(angle)*radius,hasChildren:byParent.has(node.key)});}offset+=count;ring++;}
  return {card,x:0,y:0,radius,people,total:nodes.length};
 });
 const extent=Math.max(0,...groups.map(group=>group.radius)),hubRadius=Math.max(245,(extent?extent+140:110)/Math.sin(Math.PI/Math.max(2,cards.length))),size=2*(hubRadius+extent+120),center=size/2;
 groups.forEach((group,index)=>{const angle=-Math.PI/2+index*2*Math.PI/groups.length;group.x=center+Math.cos(angle)*hubRadius;group.y=center+Math.sin(angle)*hubRadius;group.people.forEach(person=>{person.x+=group.x;person.y+=group.y;});});
 return {groups,size,center};
}
