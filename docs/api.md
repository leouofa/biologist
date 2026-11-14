# Biologist REST API (`/api/v1`) Specification & Developer Reference

This document provides a comprehensive technical reference for the programmatic REST API exposed by **Biologist** under `/api/v1`. The API is designed for external applications, researchers, and companion client environments to query, manipulate, and orchestrate the entire biological taxonomy catalog, vector embedding manifold, archetype clustering engine, and multi-stage LLM synthesis pipelines.

---

## 1. Architectural Overview & Conventions

### Base URL
```
http://localhost:3000/api/v1
```

### OpenAPI 3.1 Specification
Biologist serves an introspectable OpenAPI 3.1 JSON document directly at:
```http
GET /api/v1/openapi.json
```

### Response Envelopes
All responses are formatted as JSON using a consistent envelope structure:

#### Single Resource or Action Response
```json
{
  "data": { ... },
  "meta": { ... }
}
```

#### Collection Response (with Pagination)
```json
{
  "data": [ ... ],
  "meta": {
    "total": 42,
    "limit": 50,
    "offset": 0
  }
}
```

#### Error Response
Standard HTTP status codes (`400 Bad Request`, `404 Not Found`, `422 Unprocessable Entity`, etc.) return an error object:
```json
{
  "error": {
    "code": "not_found",
    "message": "Couldn't find Species with 'id'=9999",
    "details": ["Optional validation errors or context"]
  }
}
```

### Pagination
Collection endpoints support `limit` (default: `50`, maximum: `500`) and `offset` (default: `0`) query parameters.

### Embedding Vectors (`pgvector` 1024-float arrays)
To keep network payloads lean, endpoints returning `Species` or `Organism` records include vector metadata (`embedded: boolean`, `embedding_model: string`, `embedded_at: timestamp`, `embedding_dimensions: 1024`), while the raw 1024-float array is omitted by default.
Pass `?include_embedding=true` on any individual or collection query to include the raw vector:
```json
{
  "data": {
    "id": 1,
    "name": "Lion",
    "embedded": true,
    "embedding_model": "qwen3-embedding:0.6b",
    "embedding": [0.0123, -0.0456, 0.0891]
  }
}
```

### Synchronous vs. Asynchronous Job Execution (`?sync=true`)
Long-running LLM and embedding operations (discovery, population, vector calculation) default to asynchronous execution via ActiveJob/Sidekiq (`202 Accepted` with `{ "data": { "job_id": "...", "status": "queued" } }`).
Clients can:
1. Poll the job status at `GET /api/v1/jobs/:id`.
2. Or pass `?sync=true` on single-entity actions (`POST /api/v1/species/:id/generate_embedding?sync=true`, `POST /api/v1/biomes/:id/populate_species?sync=true`, `POST /api/v1/species/:id/populate_organisms?sync=true`) to block until execution completes and receive the immediate result (`200 OK`).

---

## 2. Resource Endpoints

### 2.1 Biomes (`/api/v1/biomes`)

- `GET /api/v1/biomes`: List biomes (supports `q`, `limit`, `offset`, `include_species`)
- `POST /api/v1/biomes`: Create a new biome
- `GET /api/v1/biomes/:id`: Retrieve biome by ID
- `PATCH /api/v1/biomes/:id`: Update biome
- `DELETE /api/v1/biomes/:id`: Delete biome
- `POST /api/v1/biomes/populate`: Trigger automated discovery of major biomes
- `POST /api/v1/biomes/:id/populate_species`: Discover species for a specific biome
- `POST /api/v1/biomes/upsert_batch`: Bulk upsert biome records

### 2.2 Species & Populations (`/api/v1/species`)

- `GET /api/v1/species`: List species (supports `biome_id`, `theme`, `q`, `embedded`, `include_embedding`, `include_organisms`)
- `POST /api/v1/species`: Create a species record
- `GET /api/v1/species/:id`: Retrieve species details
- `PATCH /api/v1/species/:id`: Update species details
- `DELETE /api/v1/species/:id`: Delete a species
- `GET /api/v1/species/:id/neighbors`: Find nearest cosine-distance species neighbors
- `POST /api/v1/species/:id/generate_embedding`: Generate or refresh 1024-d embedding vector
- `POST /api/v1/species/:id/populate_organisms`: Discover individual organisms for this species
- `POST /api/v1/species/populate`: Discover species across all biomes
- `POST /api/v1/species/upsert_batch`: Bulk upsert species for a given `biome_id`
- `GET /api/v1/species/search`: Semantic vector and keyword search across species

### 2.3 Individual Organisms (`/api/v1/organisms`)

- `GET /api/v1/organisms`: List individual organisms (supports `species_id`, `biome_id`, `theme`, `q`, `embedded`, `include_embedding`)
- `POST /api/v1/organisms`: Create an individual organism record
- `GET /api/v1/organisms/:id`: Retrieve individual organism details
- `PATCH /api/v1/organisms/:id`: Update individual organism details
- `DELETE /api/v1/organisms/:id`: Delete an individual organism
- `GET /api/v1/organisms/:id/neighbors`: Find nearest organism counterparts
- `POST /api/v1/organisms/:id/generate_embedding`: Generate 1024-d embedding vector
- `POST /api/v1/organisms/populate`: Discover individual organisms across all species
- `POST /api/v1/organisms/upsert_batch`: Bulk upsert organisms for a given `species_id`
- `GET /api/v1/organisms/search`: Semantic vector and keyword search across individual organisms

### 2.4 Clustering & Snapshots (`/api/v1/clusters`, `/api/v1/cluster_snapshots`)

- `GET /api/v1/clusters`: Dynamically compute agglomerative clusters for `Species` or `Organism` across levels 1 to 15 (params: `target_type`, `level`, `full_coverage`, `force`)
- `GET /api/v1/cluster_snapshots`: List frozen cluster snapshots
- `POST /api/v1/clusters/snapshot`: Compute and persist a frozen cluster snapshot
- `GET /api/v1/cluster_snapshots/:id`: Retrieve snapshot details, clusters, and member records
- `DELETE /api/v1/cluster_snapshots/:id`: Delete snapshot

### 2.5 Multi-Stage AI Synthesis Reports (`/api/v1/cluster_reports`)

- `GET /api/v1/cluster_reports`: List synthesis reports
- `POST /api/v1/cluster_reports`: Run 2-phase Map-Reduce report on a saved snapshot
- `POST /api/v1/cluster_reports/:id/deep_synthesis`: Run 3-phase Hierarchical Deep Synthesis report
- `GET /api/v1/cluster_reports/:id`: Retrieve completed or running report details and synthesis monograph
- `DELETE /api/v1/cluster_reports/:id`: Delete report

### 2.6 Semantic Search & Discovery (`/api/v1/search`)

- `GET /api/v1/search`: Unified cross-entity search endpoint across species and individual organisms

### 2.7 Platform Status, Jobs & Settings (`/api/v1/status`, `/api/v1/settings`, `/api/v1/jobs`)

- `GET /api/v1/status`: Health check, database connectivity, `pgvector` version, Ollama reachability, counts of biomes, species, organisms, and embeddings
- `GET /api/v1/settings`: Current LLM and embedding model configuration, context window sizes, temperature settings
- `PATCH /api/v1/settings/context_window`: Update runtime LLM context window size
- `POST /api/v1/settings/generate_embeddings`: Trigger background embedding generation for all un-embedded records
- `GET /api/v1/jobs`: List background jobs
- `GET /api/v1/jobs/:id`: Retrieve status of a queued or running job
