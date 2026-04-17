#!/usr/bin/env python
"""Generate a Mermaid architecture diagram from Helm template output.

Usage:
    helm template diracx ./diracx [--set ...] | python scripts/generate_mermaid_diagram.py [-o OUTPUT]

Reads multi-document Kubernetes YAML from stdin and writes a Mermaid flowchart
to stdout (or to a file with -o).
"""

from __future__ import annotations

import argparse
import re
import sys

import yaml

# Mermaid node shape by K8s kind
KIND_SHAPES = {
    "Deployment": ("[", "]"),
    "StatefulSet": ("[", "]"),
    "CronJob": ("([", "])"),
    "Service": ("((", "))"),
    "Ingress": ("{{", "}}"),
    "Job": ("([", "])"),
    "ConfigMap": ("[(", ")]"),
    "Secret": (">", "]"),
    "ServiceAccount": ("[[", "]]"),
}

# Display prefixes by kind
KIND_PREFIXES = {
    "Deployment": "deploy",
    "StatefulSet": "sts",
    "CronJob": "cronjob",
    "Service": "svc",
    "Ingress": "ing",
    "Job": "job",
    "ConfigMap": "cm",
    "Secret": "secret",
    "ServiceAccount": "sa",
}

# Kinds we track (others are silently ignored)
TRACKED_KINDS = set(KIND_PREFIXES)

# Strip random suffixes from job names (e.g. "diracx-init-keystore-1-tng" -> "diracx-init-keystore")
RANDOM_SUFFIX_RE = re.compile(r"-\d+-[a-z0-9]{2,4}$")


def node_key(kind: str, name: str) -> str:
    """Create a unique key for a resource (kind + name)."""
    return f"{kind}/{name}"


def node_id(kind: str, name: str) -> str:
    """Create a valid Mermaid node ID from kind and name."""
    prefix = KIND_PREFIXES.get(kind, kind.lower())
    return f"{prefix}_{name}".replace("-", "_").replace(".", "_")


def node_decl(kind: str, name: str) -> str:
    """Generate a Mermaid node declaration."""
    nid = node_id(kind, name)
    prefix = KIND_PREFIXES.get(kind, kind.lower())
    label = f"{prefix}: {name}"
    open_shape, close_shape = KIND_SHAPES.get(kind, ("[", "]"))
    return f"{nid}{open_shape}\"{label}\"{close_shape}"


def strip_job_suffix(name: str) -> str:
    """Remove the revision-random suffix from job names for determinism."""
    return RANDOM_SUFFIX_RE.sub("", name)


def parse_manifests(stream: str) -> list[dict]:
    """Parse multi-document YAML into a list of K8s resource dicts."""
    resources = []
    for doc in yaml.safe_load_all(stream):
        if doc and isinstance(doc, dict) and "kind" in doc:
            resources.append(doc)
    return resources


class Resource:
    """Parsed K8s resource with metadata."""

    def __init__(self, raw: dict):
        self.kind = raw["kind"]
        self.raw_name = raw["metadata"]["name"]
        self.name = (
            strip_job_suffix(self.raw_name) if self.kind == "Job" else self.raw_name
        )
        self.key = node_key(self.kind, self.name)
        annotations = raw.get("metadata", {}).get("annotations", {}) or {}
        self.hook = annotations.get("helm.sh/hook")
        self.raw = raw

    @property
    def is_hooked(self) -> bool:
        return self.hook is not None


def extract_chart_metadata(resources: list[dict]) -> tuple[str, str]:
    """Extract chart name and version from resource labels."""
    for r in resources:
        labels = r.get("metadata", {}).get("labels", {}) or {}
        chart_label = labels.get("helm.sh/chart", "")
        if chart_label:
            # e.g. "diracx-1.0.18" -> ("diracx", "1.0.18")
            parts = chart_label.rsplit("-", 1)
            if len(parts) == 2:
                return parts[0], parts[1]
    return "diracx", "unknown"


def extract_relationships(
    resources: list[Resource],
) -> tuple[list[tuple[str, str, str]], dict[str, str]]:
    """Extract edges and node metadata from K8s resources.

    Returns:
        edges: list of (source_key, target_key, label) tuples
        nodes: dict of {key: kind}
    """
    nodes: dict[str, str] = {}
    edges: list[tuple[str, str, str]] = []

    by_kind: dict[str, dict[str, Resource]] = {}
    for r in resources:
        if r.kind not in TRACKED_KINDS:
            continue
        nodes[r.key] = r.kind
        by_kind.setdefault(r.kind, {})[r.name] = r

    def find_target(target_name: str, preferred_kinds: list[str]) -> str | None:
        for k in preferred_kinds:
            key = node_key(k, target_name)
            if key in nodes:
                return key
        return None

    # Service -> Deployment/StatefulSet (via selector matching)
    for svc_name, svc_res in by_kind.get("Service", {}).items():
        selector = svc_res.raw.get("spec", {}).get("selector", {})
        if not selector:
            continue
        for workload_kind in ("Deployment", "StatefulSet"):
            for dep_name, dep_res in by_kind.get(workload_kind, {}).items():
                match_labels = (
                    dep_res.raw.get("spec", {})
                    .get("selector", {})
                    .get("matchLabels", {})
                )
                if all(match_labels.get(k) == v for k, v in selector.items()):
                    edges.append(
                        (
                            node_key("Service", svc_name),
                            node_key(workload_kind, dep_name),
                            "routes to",
                        )
                    )

    # Ingress -> Service (via backend rules)
    for ing_name, ing_res in by_kind.get("Ingress", {}).items():
        for rule in ing_res.raw.get("spec", {}).get("rules", []):
            for path_entry in rule.get("http", {}).get("paths", []):
                backend_svc = (
                    path_entry.get("backend", {}).get("service", {}).get("name")
                )
                path = path_entry.get("path", "/")
                if backend_svc and node_key("Service", backend_svc) in nodes:
                    edges.append(
                        (
                            node_key("Ingress", ing_name),
                            node_key("Service", backend_svc),
                            path,
                        )
                    )

    # Workloads -> ConfigMap/Secret/ServiceAccount (via volumes, envFrom)
    for kind in ("Deployment", "StatefulSet", "Job", "CronJob"):
        for res_name, res in by_kind.get(kind, {}).items():
            src_key = res.key

            if kind == "CronJob":
                # CronJob: spec.jobTemplate.spec.template.spec
                pod_spec = (
                    res.raw.get("spec", {})
                    .get("jobTemplate", {})
                    .get("spec", {})
                    .get("template", {})
                    .get("spec", {})
                )
            else:
                pod_spec = res.raw.get("spec", {}).get("template", {}).get("spec", {})
            if not pod_spec:
                continue

            for vol in pod_spec.get("volumes", []) or []:
                cm = vol.get("configMap", {})
                if cm:
                    target = find_target(cm.get("name", ""), ["ConfigMap"])
                    if target:
                        edges.append((src_key, target, "mounts"))
                sec = vol.get("secret", {})
                if sec:
                    target = find_target(sec.get("secretName", ""), ["Secret"])
                    if target:
                        edges.append((src_key, target, "mounts"))

            for container_list in ("containers", "initContainers"):
                for container in pod_spec.get(container_list, []) or []:
                    for env_ref in container.get("envFrom", []) or []:
                        cm_ref = env_ref.get("configMapRef", {})
                        if cm_ref:
                            target = find_target(
                                cm_ref.get("name", ""), ["ConfigMap"]
                            )
                            if target:
                                edges.append((src_key, target, "env"))
                        sec_ref = env_ref.get("secretRef", {})
                        if sec_ref:
                            target = find_target(sec_ref.get("name", ""), ["Secret"])
                            if target:
                                edges.append((src_key, target, "env"))

            sa_name = pod_spec.get("serviceAccountName")
            if sa_name:
                target = find_target(sa_name, ["ServiceAccount"])
                if target:
                    edges.append((src_key, target, "uses"))

    # Deduplicate edges
    edges = list(dict.fromkeys(edges))

    return edges, nodes


def generate_mermaid(
    resources: list[Resource],
    nodes: dict[str, str],
    edges: list[tuple[str, str, str]],
    chart_name: str,
    chart_version: str,
    release_name: str,
) -> str:
    """Generate Mermaid flowchart with subgraphs and styling."""
    lines: list[str] = []

    # Header with ELK layout for better automatic positioning
    lines.append("---")
    lines.append("config:")
    lines.append("  layout: elk")
    lines.append("---")
    lines.append("flowchart TD")

    # Separate resources into hook groups and main application
    hook_groups: dict[str, list[Resource]] = {}
    app_resources: list[Resource] = []

    for r in resources:
        if r.key not in nodes:
            continue
        if r.is_hooked:
            hook_groups.setdefault(r.hook, []).append(r)
        else:
            app_resources.append(r)

    # -- Main application subgraph --
    indent = "    "
    lines.append("")
    lines.append(f"{indent}subgraph k8s_instance [\"K8s Instance: {release_name}\"]")
    lines.append(
        f"{indent}{indent}subgraph helm_chart"
        f" [\"Helm Chart: {chart_name} {chart_version}\"]"
    )
    lines.append(
        f"{indent}{indent}{indent}subgraph k8s_app [\"K8s Application: {release_name}\"]"
    )

    # Emit app resources grouped by kind
    kinds_order = [
        "Ingress",
        "Service",
        "Deployment",
        "StatefulSet",
        "CronJob",
        "ConfigMap",
        "Secret",
        "ServiceAccount",
    ]
    for kind in kinds_order:
        kind_res = sorted(
            [r for r in app_resources if r.kind == kind], key=lambda r: r.name
        )
        if not kind_res:
            continue
        for r in kind_res:
            lines.append(f"{indent}{indent}{indent}{indent}{node_decl(r.kind, r.name)}")

    lines.append(f"{indent}{indent}{indent}end")

    # -- Hook subgraphs (inside helm chart, outside k8s app) --
    # Sort hook groups for deterministic output
    for hook_label in sorted(hook_groups):
        safe_id = hook_label.replace(",", "_").replace("-", "_")
        hook_res = sorted(hook_groups[hook_label], key=lambda r: (r.kind, r.name))
        lines.append("")
        lines.append(
            f"{indent}{indent}{indent}subgraph hook_{safe_id} [\"{hook_label}\"]"
        )
        for r in hook_res:
            lines.append(f"{indent}{indent}{indent}{indent}{node_decl(r.kind, r.name)}")
        lines.append(f"{indent}{indent}{indent}end")

    lines.append(f"{indent}{indent}end")
    lines.append(f"{indent}end")

    # -- Edges --
    lines.append("")
    lines.append(f"{indent}%% Relationships")
    for src_key, dst_key, label in edges:
        src_kind, src_name = src_key.split("/", 1)
        dst_kind, dst_name = dst_key.split("/", 1)
        src_nid = node_id(src_kind, src_name)
        dst_nid = node_id(dst_kind, dst_name)
        lines.append(f"{indent}{src_nid} -->|\"{label}\"| {dst_nid}")

    # -- Styling --
    # Uses CSS variables that adapt to light/dark mode in mkdocs-material,
    # with sensible fallback colors for plain Mermaid renderers.
    lines.append("")
    lines.append(f"{indent}%% Styling")

    # Style classes per kind - blue tones that work on both light and dark backgrounds
    kind_colors = {
        "Ingress": ("#4a90d9", "#ffffff"),
        "Service": ("#5ba3e6", "#ffffff"),
        "Deployment": ("#3b7dd8", "#ffffff"),
        "StatefulSet": ("#3b7dd8", "#ffffff"),
        "Job": ("#6db3f2", "#1a1a2e"),
        "CronJob": ("#6db3f2", "#1a1a2e"),
        "ConfigMap": ("#7ec8e3", "#1a1a2e"),
        "Secret": ("#a78bfa", "#ffffff"),
        "ServiceAccount": ("#94a3b8", "#ffffff"),
    }
    for kind, (bg, fg) in kind_colors.items():
        class_name = KIND_PREFIXES.get(kind, kind.lower())
        lines.append(
            f"{indent}classDef {class_name} fill:{bg},stroke:#2563eb,color:{fg}"
        )

    # Apply classes to nodes
    for key, kind in sorted(nodes.items()):
        name = key.split("/", 1)[1]
        class_name = KIND_PREFIXES.get(kind, kind.lower())
        lines.append(f"{indent}class {node_id(kind, name)} {class_name}")

    # Subgraph styling
    lines.append(f"{indent}style k8s_instance fill:none,stroke:#60a5fa,stroke-width:2px,color:#60a5fa")
    lines.append(f"{indent}style helm_chart fill:none,stroke:#93c5fd,stroke-width:1px,stroke-dasharray:5 5,color:#93c5fd")
    lines.append(f"{indent}style k8s_app fill:#3b82f610,stroke:#3b82f6,stroke-width:1px,color:#3b82f6")

    for hook_label in sorted(hook_groups):
        safe_id = hook_label.replace(",", "_").replace("-", "_")
        lines.append(
            f"{indent}style hook_{safe_id} fill:#10b98110,stroke:#10b981,stroke-width:1px,color:#10b981"
        )

    lines.append("")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Generate Mermaid diagram from Kubernetes YAML manifests"
    )
    parser.add_argument(
        "-o",
        "--output",
        help="Output file path (default: stdout)",
    )
    parser.add_argument(
        "--release-name",
        default="diracx",
        help="Helm release name for subgraph labels (default: diracx)",
    )
    args = parser.parse_args()

    stdin_data = sys.stdin.read()
    if not stdin_data.strip():
        print("Error: no input received on stdin", file=sys.stderr)
        sys.exit(1)

    raw_resources = parse_manifests(stdin_data)
    if not raw_resources:
        print("Error: no Kubernetes resources found in input", file=sys.stderr)
        sys.exit(1)

    chart_name, chart_version = extract_chart_metadata(raw_resources)
    resources = [Resource(r) for r in raw_resources]

    edges, nodes = extract_relationships(resources)
    diagram = generate_mermaid(
        resources, nodes, edges, chart_name, chart_version, args.release_name
    )

    if args.output:
        with open(args.output, "w") as f:
            f.write(diagram)
        print(f"Diagram written to {args.output}", file=sys.stderr)
    else:
        print(diagram)


if __name__ == "__main__":
    main()
