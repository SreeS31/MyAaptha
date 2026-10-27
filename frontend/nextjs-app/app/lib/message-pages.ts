/** Merge cursor pages and refresh matching records without dropping loaded history.
 * A disjoint newer page resets the window so "earlier" can retrieve a missed gap.
 */
export function mergeMessagePage<T extends {id:number}>(current:T[],page:T[]):T[]{
  if(!page.length)return current;
  if(current.length&&page[0].id>current[current.length-1].id&&page.length===50)return page;
  const values=new Map(current.map(item=>[item.id,item]));
  for(const item of page)values.set(item.id,item);
  return Array.from(values.values()).sort((a,b)=>a.id-b.id);
}
