import type { NetworkRelationship } from '../lib/api';
export type Person = { id: number; name: string; gender?: string | null; relationship?: NetworkRelationship | null };
export type Edge = { source: number; target: number };

// A spanning tree gives shared relatives one position and makes cycles safe.
export function buildChain(people: Person[], edges: Edge[], root: number, expanded: Set<number>) {
  const known = new Set(people.map(person => person.id));
  const adjacent = new Map<number, number[]>();
  for (const edge of edges) {
    if (!known.has(edge.source) || !known.has(edge.target) || edge.source === edge.target) continue;
    for (const [a, b] of [[edge.source, edge.target], [edge.target, edge.source]]) {
      const list = adjacent.get(a) || [];
      if (!list.includes(b)) list.push(b);
      adjacent.set(a, list);
    }
  }
  const parents = new Map<number, number>();
  const children = new Map<number, number[]>();
  const visited = new Set<number>();
  const roots: number[] = [];
  for (const start of [root, ...people.map(person => person.id)]) {
    if (visited.has(start) || !known.has(start)) continue;
    roots.push(start); visited.add(start);
    const queue = [start];
    for (let index = 0; index < queue.length; index++) {
      const id = queue[index];
      for (const next of adjacent.get(id) || []) {
        if (visited.has(next)) continue;
        visited.add(next); parents.set(next, id); queue.push(next);
        children.set(id, [...(children.get(id) || []), next]);
      }
    }
  }
  // Keep disconnected records discoverable without inventing a relationship.
  const positions = new Map<number, { x: number; y: number }>();
  let row = 0;
  const stack = roots.slice().reverse().map(id => ({ id, depth: 0, finish: false }));
  while (stack.length) {
    const item = stack.pop()!;
    const visibleChildren = expanded.has(item.id) ? children.get(item.id) || [] : [];
    if (item.finish) {
      const first = positions.get(visibleChildren[0])!;
      const last = positions.get(visibleChildren[visibleChildren.length - 1])!;
      positions.set(item.id, { x: 40 + item.depth * 270, y: (first.y + last.y) / 2 });
    } else if (visibleChildren.length) {
      stack.push({ ...item, finish: true });
      for (const id of visibleChildren.slice().reverse()) stack.push({ id, depth: item.depth + 1, finish: false });
    } else positions.set(item.id, { x: 40 + item.depth * 270, y: 40 + row++ * 78 });
  }
  return { positions, children, parents };
}
