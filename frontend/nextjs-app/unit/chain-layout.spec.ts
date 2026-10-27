import { test, expect } from '@playwright/test';
import { buildChain } from '../app/dashboard/chain-layout';

test('branches expand independently and shared relatives do not create cycles', () => {
  const people = [0, 1, 2, 3].map(id => ({ id, name: String(id) }));
  const edges = [{source:0,target:1},{source:1,target:2},{source:2,target:3},{source:3,target:1}];
  const collapsed = buildChain(people, edges, 0, new Set([0]));
  expect(Array.from(collapsed.positions.keys()).sort()).toEqual([0, 1]);
  const expanded = buildChain(people, edges, 0, new Set([0, 1, 2, 3]));
  expect(expanded.positions.size).toBe(4);
  expect(expanded.parents.size).toBe(3);
  expect(new Set(Array.from(expanded.positions.values()).map(p => `${p.x},${p.y}`)).size).toBe(4);
});

test('large deep chains have no depth limit or recursive stack dependency', () => {
  const people = Array.from({length:2000}, (_, id) => ({id, name:String(id)}));
  const edges = people.slice(1).map(person => ({source:person.id-1,target:person.id}));
  const graph = buildChain(people, edges, 0, new Set(people.map(person => person.id)));
  expect(graph.positions.size).toBe(2000);
  expect(graph.positions.get(1999)?.x).toBe(40 + 1999 * 270);
});

test('unknown endpoints and disconnected people remain safe', () => {
  const graph = buildChain([{id:0,name:'Me'},{id:1,name:'Unlinked'}], [{source:0,target:99}], 0, new Set([0]));
  expect(graph.positions.size).toBe(2);
  expect(graph.parents.has(1)).toBe(false);
});

test('disconnected chains can also be expanded to their end', () => {
  const people = [0,1,2].map(id => ({id,name:String(id)}));
  const graph = buildChain(people, [{source:1,target:2}], 0, new Set([0,1]));
  expect(graph.children.get(1)).toEqual([2]);
  expect(graph.positions.get(2)?.x).toBe(310);
});
