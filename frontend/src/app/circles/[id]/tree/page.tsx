'use client';

import { useCallback, useEffect, useState } from 'react';
import { useParams } from 'next/navigation';
import {
  ReactFlow,
  Background,
  Controls,
  MiniMap,
  Node,
  Edge,
  useNodesState,
  useEdgesState,
  addEdge,
  Connection,
  Handle,
  Position,
} from '@xyflow/react';
import '@xyflow/react/dist/style.css';
import { useQuery } from '@tanstack/react-query';
import { api, ApiResponse } from '@/lib/api';
import { motion } from 'framer-motion';

interface NodeData extends Record<string, unknown> {
  id: string;
  fullName: string;
  gender: 'MALE' | 'FEMALE' | 'UNKNOWN';
  age?: number;
  profilePictureUrl?: string;
}

const genderColors = {
  MALE: 'bg-blue-200 border-blue-400',
  FEMALE: 'bg-pink-200 border-pink-400',
  UNKNOWN: 'bg-gray-200 border-gray-400',
};

function PersonNodeCard({ data }: { data: NodeData }) {
  return (
    <div className={`rounded-xl border-2 px-4 py-3 shadow-md ${genderColors[data.gender] ?? genderColors.UNKNOWN}`}>
      <Handle type="target" position={Position.Top} />
      <div className="text-sm font-semibold">{data.fullName}</div>
      {data.age != null && <div className="text-xs text-gray-600">{data.age} yrs</div>}
      <Handle type="source" position={Position.Bottom} />
    </div>
  );
}

const nodeTypes = { person: PersonNodeCard };

export default function TreePage() {
  const params = useParams();
  const circleId = params.id as string;
  const [nodes, setNodes, onNodesChange] = useNodesState<Node>([]);
  const [edges, setEdges, onEdgesChange] = useEdgesState<Edge>([]);

  const { data: roots } = useQuery({
    queryKey: ['tree-roots', circleId],
    queryFn: async () => {
      const { data } = await api.get<ApiResponse<NodeData[]>>(`/api/v1/circles/${circleId}/nodes/roots`);
      return data.data;
    },
  });

  useEffect(() => {
    if (!roots) return;
    const flowNodes: Node[] = roots.map((n, i) => ({
      id: n.id,
      type: 'person',
      position: { x: i * 220, y: 0 },
      data: n,
    }));
    setNodes(flowNodes);
    setEdges([]);
  }, [roots, setNodes, setEdges]);

  const onConnect = useCallback(
    (params: Connection) => setEdges((eds) => addEdge({ ...params, label: 'relation' }, eds)),
    [setEdges]
  );

  const onNodeClick = useCallback(async (_: React.MouseEvent, node: Node) => {
    const { data } = await api.get<ApiResponse<NodeData[]>>(
      `/api/v1/circles/${circleId}/nodes/${node.id}/children`
    );
    const children = data.data;
    setNodes((nds) => {
      const existing = new Set(nds.map((n) => n.id));
      const newNodes = children
        .filter((c) => !existing.has(c.id))
        .map((c, i) => ({
          id: c.id,
          type: 'person' as const,
          position: { x: node.position.x + (i - children.length / 2) * 180, y: node.position.y + 150 },
          data: c,
        }));
      return [...nds, ...newNodes];
    });
    setEdges((eds) => [
      ...eds,
      ...children.map((c) => ({
        id: `${node.id}-${c.id}`,
        source: node.id,
        target: c.id,
        label: 'child',
      })),
    ]);
  }, [circleId, setNodes, setEdges]);

  return (
    <div className="flex h-screen flex-col">
      <header className="border-b bg-white px-6 py-3 dark:border-gray-800 dark:bg-gray-900">
        <motion.h1 initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="font-bold">
          Tree Visualization
        </motion.h1>
        <p className="text-sm text-gray-500">Click a node to expand children (lazy load)</p>
      </header>
      <div className="flex-1">
        <ReactFlow
          nodes={nodes}
          edges={edges}
          onNodesChange={onNodesChange}
          onEdgesChange={onEdgesChange}
          onConnect={onConnect}
          onNodeClick={onNodeClick}
          nodeTypes={nodeTypes}
          fitView
        >
          <Background />
          <Controls />
          <MiniMap />
        </ReactFlow>
      </div>
    </div>
  );
}
