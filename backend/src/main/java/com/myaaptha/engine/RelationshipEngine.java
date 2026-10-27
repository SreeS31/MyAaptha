package com.myaaptha.engine;

import com.myaaptha.domain.relationship.Relationship;
import com.myaaptha.repository.RelationshipRepository;
import lombok.Builder;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.*;

@Component
@RequiredArgsConstructor
public class RelationshipEngine {

    private final RelationshipRepository relationshipRepository;

    private static final Map<String, String> INVERSE = Map.ofEntries(
            Map.entry("FATHER", "SON"),
            Map.entry("MOTHER", "DAUGHTER"),
            Map.entry("SON", "FATHER"),
            Map.entry("DAUGHTER", "MOTHER"),
            Map.entry("BROTHER", "BROTHER"),
            Map.entry("SISTER", "SISTER"),
            Map.entry("SPOUSE", "SPOUSE"),
            Map.entry("FRIEND", "FRIEND"),
            Map.entry("COLLEAGUE", "COLLEAGUE")
    );

    public KinshipResult resolve(UUID fromNodeId, UUID toNodeId) {
        if (fromNodeId.equals(toNodeId)) {
            return KinshipResult.builder()
                    .label("Self")
                    .path(List.of())
                    .distance(0)
                    .build();
        }

        List<Relationship> allRels = relationshipRepository
                .findBySourceNodeIdOrTargetNodeId(fromNodeId, fromNodeId);
        allRels.addAll(relationshipRepository.findBySourceNodeIdOrTargetNodeId(toNodeId, toNodeId));

        Map<UUID, List<Edge>> graph = buildGraph(allRels);
        List<String> path = bfsPath(graph, fromNodeId, toNodeId);

        if (path.isEmpty()) {
            return KinshipResult.builder()
                    .label("Unknown")
                    .path(List.of())
                    .distance(-1)
                    .build();
        }

        String label = composeLabel(path);
        return KinshipResult.builder()
                .label(label)
                .path(path)
                .distance(path.size())
                .bloodRelation(isBloodRelation(path))
                .build();
    }

    private Map<UUID, List<Edge>> buildGraph(List<Relationship> relationships) {
        Map<UUID, List<Edge>> graph = new HashMap<>();
        for (Relationship rel : relationships) {
            graph.computeIfAbsent(rel.getSourceNodeId(), k -> new ArrayList<>())
                    .add(new Edge(rel.getTargetNodeId(), rel.getRelationshipType()));
            if (Boolean.TRUE.equals(rel.getBidirectional()) ||
                    "SPOUSE".equals(rel.getRelationshipType()) ||
                    "FRIEND".equals(rel.getRelationshipType())) {
                String inverse = INVERSE.getOrDefault(rel.getRelationshipType(), rel.getRelationshipType());
                graph.computeIfAbsent(rel.getTargetNodeId(), k -> new ArrayList<>())
                        .add(new Edge(rel.getSourceNodeId(), inverse));
            }
        }
        return graph;
    }

    private List<String> bfsPath(Map<UUID, List<Edge>> graph, UUID start, UUID end) {
        Queue<UUID> queue = new LinkedList<>();
        Map<UUID, UUID> parent = new HashMap<>();
        Map<UUID, String> edgeLabel = new HashMap<>();
        Set<UUID> visited = new HashSet<>();

        queue.add(start);
        visited.add(start);

        while (!queue.isEmpty()) {
            UUID current = queue.poll();
            if (current.equals(end)) break;

            for (Edge edge : graph.getOrDefault(current, List.of())) {
                if (!visited.contains(edge.target())) {
                    visited.add(edge.target());
                    parent.put(edge.target(), current);
                    edgeLabel.put(edge.target(), edge.type());
                    queue.add(edge.target());
                }
            }
        }

        if (!visited.contains(end)) return List.of();

        LinkedList<String> path = new LinkedList<>();
        UUID node = end;
        while (parent.containsKey(node)) {
            path.addFirst(edgeLabel.get(node));
            node = parent.get(node);
        }
        return path;
    }

    private String composeLabel(List<String> path) {
        if (path.size() == 1) return capitalize(path.get(0));
        // Simplified composition rules
        if (path.equals(List.of("FATHER", "BROTHER", "SON"))) return "Cousin";
        if (path.equals(List.of("MOTHER", "BROTHER", "SON"))) return "Cousin";
        if (path.equals(List.of("SPOUSE", "FATHER"))) return "Father-in-law";
        if (path.equals(List.of("SPOUSE", "MOTHER"))) return "Mother-in-law";
        return String.join(" → ", path.stream().map(this::capitalize).toList());
    }

    private boolean isBloodRelation(List<String> path) {
        Set<String> blood = Set.of("FATHER", "MOTHER", "SON", "DAUGHTER", "BROTHER", "SISTER");
        return path.stream().anyMatch(blood::contains);
    }

    private String capitalize(String s) {
        return s.substring(0, 1).toUpperCase() + s.substring(1).toLowerCase().replace('_', ' ');
    }

    private record Edge(UUID target, String type) {}

    @Data
    @Builder
    public static class KinshipResult {
        private String label;
        private List<String> path;
        private int distance;
        private Boolean bloodRelation;
    }
}
