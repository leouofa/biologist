# frozen_string_literal: true

module Api
  module V1
    class OpenapiSpec
      def self.generate
        {
          openapi: "3.1.0",
          info: {
            title: "Biologist Platform REST API",
            version: "1.0.0",
            description: "Full programmatic REST API for the Biologist computational laboratory for comparative ecology, species populations, and organismal biology."
          },
          servers: [
            { url: "/api/v1", description: "Default v1 endpoint" }
          ],
          paths: {
            "/status" => {
              get: {
                summary: "Platform status, health, and entity statistics",
                operationId: "getPlatformStatus",
                responses: {
                  "200" => { description: "Current platform status and counts" }
                }
              }
            },
            "/openapi.json" => {
              get: {
                summary: "OpenAPI 3.1 specification for Biologist",
                operationId: "getOpenapiSpec",
                responses: {
                  "200" => { description: "OpenAPI schema document" }
                }
              }
            },
            "/search" => {
              get: {
                summary: "Cross-resource semantic or keyword search across Species and Organisms",
                operationId: "searchAll",
                parameters: [
                  { name: "q", in: "query", required: true, schema: { type: "string" } },
                  { name: "mode", in: "query", required: false, schema: { type: "string", enum: %w[semantic keyword auto], default: "auto" } },
                  { name: "target_type", in: "query", required: false, schema: { type: "string", enum: %w[all species organism], default: "all" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 20 } }
                ],
                responses: {
                  "200" => { description: "Search results with similarity distances" }
                }
              }
            },
            "/biomes" => {
              get: {
                summary: "List biomes",
                operationId: "listBiomes",
                parameters: [
                  { name: "q", in: "query", required: false, schema: { type: "string" } },
                  { name: "include_species", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of biomes" } }
              },
              post: {
                summary: "Create a biome",
                operationId: "createBiome",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[name description],
                        properties: {
                          name: { type: "string" },
                          description: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created biome" } }
              }
            },
            "/biomes/{id}" => {
              get: {
                summary: "Get biome details",
                operationId: "getBiome",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_species", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Biome details" } }
              },
              patch: {
                summary: "Update biome",
                operationId: "updateBiome",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          name: { type: "string" },
                          description: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Updated biome" } }
              },
              delete: {
                summary: "Delete biome",
                operationId: "deleteBiome",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Biome deleted" } }
              }
            },
            "/biomes/upsert_batch" => {
              post: {
                summary: "Batch upsert biomes",
                operationId: "batchUpsertBiomes",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[biomes],
                        properties: {
                          biomes: {
                            type: "array",
                            items: {
                              type: "object",
                              required: %w[name description],
                              properties: {
                                name: { type: "string" },
                                description: { type: "string" }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Upserted biomes" } }
              }
            },
            "/biomes/populate" => {
              post: {
                summary: "Trigger LLM discovery of biomes",
                operationId: "populateBiomes",
                parameters: [
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Sync response" }, "202" => { description: "Async job queued" } }
              }
            },
            "/biomes/{id}/populate_species" => {
              post: {
                summary: "Trigger LLM discovery of species for a single biome",
                operationId: "populateBiomeSpeciess",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Sync response" }, "202" => { description: "Async job queued" } }
              }
            },
            "/species" => {
              get: {
                summary: "List/filter species",
                operationId: "listSpeciess",
                parameters: [
                  { name: "biome_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "biome", in: "query", required: false, schema: { type: "string" } },
                  { name: "theme", in: "query", required: false, schema: { type: "string" } },
                  { name: "q", in: "query", required: false, schema: { type: "string" } },
                  { name: "embedded", in: "query", required: false, schema: { type: "boolean" } },
                  { name: "include_embedding", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "include_organisms", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of species" } }
              },
              post: {
                summary: "Create a species",
                operationId: "createSpecies",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[biome_id name description],
                        properties: {
                          biome_id: { type: "integer" },
                          name: { type: "string" },
                          description: { type: "string" },
                          themes: { type: "array", items: { type: "string" } }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created species" } }
              }
            },
            "/species/search" => {
              get: {
                summary: "Semantic or keyword search for species",
                operationId: "searchSpeciess",
                parameters: [
                  { name: "q", in: "query", required: true, schema: { type: "string" } },
                  { name: "mode", in: "query", required: false, schema: { type: "string", enum: %w[semantic keyword auto], default: "auto" } },
                  { name: "biome_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 20 } }
                ],
                responses: { "200" => { description: "Species search results" } }
              }
            },
            "/species/{id}" => {
              get: {
                summary: "Get species details",
                operationId: "getSpecies",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_embedding", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "include_organisms", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Species details" } }
              },
              patch: {
                summary: "Update species",
                operationId: "updateSpecies",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          name: { type: "string" },
                          description: { type: "string" },
                          themes: { type: "array", items: { type: "string" } },
                          biome_id: { type: "integer" }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Updated species" } }
              },
              delete: {
                summary: "Delete species",
                operationId: "deleteSpecies",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Species deleted" } }
              }
            },
            "/species/{id}/neighbors" => {
              get: {
                summary: "Nearest-neighbor species by cosine distance",
                operationId: "getSpeciesNeighbors",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 10 } },
                  { name: "biome_id", in: "query", required: false, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Nearest neighbors" } }
              }
            },
            "/species/{id}/generate_embedding" => {
              post: {
                summary: "Generate vector embedding for species",
                operationId: "generateSpeciesEmbedding",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Embedding generated" }, "202" => { description: "Job queued" } }
              }
            },
            "/species/{id}/populate_organisms" => {
              post: {
                summary: "Discover/populate organisms for a species via LLM",
                operationId: "populateSpeciesOrganisms",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Organisms created" }, "202" => { description: "Job queued" } }
              }
            },
            "/species/populate" => {
              post: {
                summary: "Trigger bulk LLM species discovery",
                operationId: "populateAllSpeciess",
                parameters: [
                  { name: "biome_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Sync response" }, "202" => { description: "Job queued" } }
              }
            },
            "/species/upsert_batch" => {
              post: {
                summary: "Batch upsert species for a biome",
                operationId: "batchUpsertSpeciess",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[biome_id species],
                        properties: {
                          biome_id: { type: "integer" },
                          species: {
                            type: "array",
                            items: {
                              type: "object",
                              required: %w[name description],
                              properties: {
                                name: { type: "string" },
                                description: { type: "string" },
                                themes: { type: "array", items: { type: "string" } }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Upserted species" } }
              }
            },
            "/organisms" => {
              get: {
                summary: "List/filter organisms",
                operationId: "listOrganisms",
                parameters: [
                  { name: "species_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "biome_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "theme", in: "query", required: false, schema: { type: "string" } },
                  { name: "q", in: "query", required: false, schema: { type: "string" } },
                  { name: "embedded", in: "query", required: false, schema: { type: "boolean" } },
                  { name: "include_embedding", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of organisms" } }
              },
              post: {
                summary: "Create a organism for a species",
                operationId: "createOrganism",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[species_id name description],
                        properties: {
                          species_id: { type: "integer" },
                          name: { type: "string" },
                          description: { type: "string" },
                          themes: { type: "array", items: { type: "string" } }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created organism" } }
              }
            },
            "/organisms/search" => {
              get: {
                summary: "Semantic or keyword search for organisms",
                operationId: "searchOrganisms",
                parameters: [
                  { name: "q", in: "query", required: true, schema: { type: "string" } },
                  { name: "mode", in: "query", required: false, schema: { type: "string", enum: %w[semantic keyword auto], default: "auto" } },
                  { name: "species_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "biome_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 20 } }
                ],
                responses: { "200" => { description: "Organism search results" } }
              }
            },
            "/organisms/{id}" => {
              get: {
                summary: "Get organism details",
                operationId: "getOrganism",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_embedding", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Organism details" } }
              },
              patch: {
                summary: "Update organism",
                operationId: "updateOrganism",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          name: { type: "string" },
                          description: { type: "string" },
                          themes: { type: "array", items: { type: "string" } }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Updated organism" } }
              },
              delete: {
                summary: "Delete organism",
                operationId: "deleteOrganism",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Organism deleted" } }
              }
            },
            "/organisms/{id}/neighbors" => {
              get: {
                summary: "Nearest-neighbor organisms by cosine distance",
                operationId: "getOrganismNeighbors",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 10 } },
                  { name: "species_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "biome_id", in: "query", required: false, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Nearest neighbors" } }
              }
            },
            "/organisms/{id}/generate_embedding" => {
              post: {
                summary: "Generate vector embedding for organism",
                operationId: "generateOrganismEmbedding",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Embedding generated" }, "202" => { description: "Job queued" } }
              }
            },
            "/organisms/populate" => {
              post: {
                summary: "Trigger bulk LLM organism discovery",
                operationId: "populateAllOrganisms",
                parameters: [
                  { name: "species_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "sync", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Sync response" }, "202" => { description: "Job queued" } }
              }
            },
            "/organisms/upsert_batch" => {
              post: {
                summary: "Batch upsert organisms for a species",
                operationId: "batchUpsertOrganisms",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[species_id organisms],
                        properties: {
                          species_id: { type: "integer" },
                          organisms: {
                            type: "array",
                            items: {
                              type: "object",
                              required: %w[name description],
                              properties: {
                                name: { type: "string" },
                                description: { type: "string" },
                                themes: { type: "array", items: { type: "string" } }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Upserted organisms" } }
              }
            },
            "/clusters" => {
              get: {
                summary: "Compute or fetch live clusters",
                operationId: "getLiveClusters",
                parameters: [
                  { name: "target_type", in: "query", required: false, schema: { type: "string", enum: %w[Species Organism], default: "Species" } },
                  { name: "level", in: "query", required: false, schema: { type: "integer", minimum: 1, maximum: 15, default: 5 } },
                  { name: "full_coverage", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "force", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Clustering result" } }
              }
            },
            "/clusters/snapshot" => {
              post: {
                summary: "Compute and save a cluster snapshot",
                operationId: "createSnapshotFromCluster",
                requestBody: {
                  required: false,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          target_type: { type: "string", enum: %w[Species Organism], default: "Species" },
                          level: { type: "integer", default: 5 },
                          full_coverage: { type: "boolean", default: false },
                          title: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Persisted ClusterSnapshot" } }
              }
            },
            "/cluster_snapshots" => {
              get: {
                summary: "List cluster snapshots",
                operationId: "listClusterSnapshots",
                parameters: [
                  { name: "target_type", in: "query", required: false, schema: { type: "string", enum: %w[Species Organism] } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of snapshots" } }
              },
              post: {
                summary: "Create and persist a snapshot",
                operationId: "createClusterSnapshot",
                requestBody: {
                  required: false,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          target_type: { type: "string", enum: %w[Species Organism], default: "Species" },
                          level: { type: "integer", default: 5 },
                          full_coverage: { type: "boolean", default: false },
                          title: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created snapshot" } }
              }
            },
            "/cluster_snapshots/{id}" => {
              get: {
                summary: "Get cluster snapshot details with groups",
                operationId: "getClusterSnapshot",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_groups", in: "query", required: false, schema: { type: "boolean", default: true } },
                  { name: "include_members", in: "query", required: false, schema: { type: "boolean", default: true } },
                  { name: "include_reports", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Snapshot details" } }
              },
              delete: {
                summary: "Delete cluster snapshot",
                operationId: "deleteClusterSnapshot",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Snapshot deleted" } }
              }
            },
            "/cluster_snapshots/{cluster_snapshot_id}/cluster_groups" => {
              get: {
                summary: "List cluster groups in a snapshot",
                operationId: "listSnapshotGroups",
                parameters: [
                  { name: "cluster_snapshot_id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_members", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "List of cluster groups" } }
              }
            },
            "/cluster_groups/{id}" => {
              get: {
                summary: "Get cluster group details with members",
                operationId: "getClusterGroup",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_members", in: "query", required: false, schema: { type: "boolean", default: true } }
                ],
                responses: { "200" => { description: "Cluster group details" } }
              }
            },
            "/cluster_reports" => {
              get: {
                summary: "List cluster reports",
                operationId: "listClusterReports",
                parameters: [
                  { name: "cluster_snapshot_id", in: "query", required: false, schema: { type: "integer" } },
                  { name: "target_type", in: "query", required: false, schema: { type: "string", enum: %w[Species Organism] } },
                  { name: "status", in: "query", required: false, schema: { type: "string" } },
                  { name: "is_detailed", in: "query", required: false, schema: { type: "boolean" } },
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 50 } },
                  { name: "offset", in: "query", required: false, schema: { type: "integer", default: 0 } }
                ],
                responses: { "200" => { description: "List of cluster reports" } }
              },
              post: {
                summary: "Create a cluster synthesis report",
                operationId: "createClusterReport",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[cluster_snapshot_id],
                        properties: {
                          cluster_snapshot_id: { type: "integer" },
                          prompt: { type: "string" }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created report" } }
              }
            },
            "/cluster_reports/{id}" => {
              get: {
                summary: "Get cluster report details",
                operationId: "getClusterReport",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } },
                  { name: "include_summaries", in: "query", required: false, schema: { type: "boolean", default: false } },
                  { name: "include_sub_reports", in: "query", required: false, schema: { type: "boolean", default: false } }
                ],
                responses: { "200" => { description: "Cluster report details" } }
              },
              delete: {
                summary: "Delete cluster report",
                operationId: "deleteClusterReport",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Report deleted" } }
              }
            },
            "/cluster_reports/{id}/deep_synthesis" => {
              post: {
                summary: "Create detailed 3-phase report from an existing report",
                operationId: "createDeepSynthesisReport",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                requestBody: {
                  required: false,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        properties: {
                          batch_size: { type: "integer", minimum: 2, maximum: 50, default: 5 }
                        }
                      }
                    }
                  }
                },
                responses: { "201" => { description: "Created deep synthesis report" } }
              }
            },
            "/cluster_reports/{cluster_report_id}/summaries" => {
              get: {
                summary: "List Phase 1 per-cluster summaries",
                operationId: "listReportSummaries",
                parameters: [
                  { name: "cluster_report_id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "List of summaries" } }
              }
            },
            "/cluster_report_summaries/{id}" => {
              get: {
                summary: "Get a single cluster report summary",
                operationId: "getReportSummary",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Summary details" } }
              }
            },
            "/cluster_reports/{cluster_report_id}/sub_reports" => {
              get: {
                summary: "List Phase 2 batch sub-reports",
                operationId: "listReportSubReports",
                parameters: [
                  { name: "cluster_report_id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "List of sub-reports" } }
              }
            },
            "/cluster_sub_reports/{id}" => {
              get: {
                summary: "Get a single batch sub-report",
                operationId: "getReportSubReport",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "integer" } }
                ],
                responses: { "200" => { description: "Sub-report details" } }
              }
            },
            "/jobs" => {
              get: {
                summary: "List recent background jobs",
                operationId: "listJobs",
                parameters: [
                  { name: "limit", in: "query", required: false, schema: { type: "integer", default: 20 } }
                ],
                responses: { "200" => { description: "Recent jobs" } }
              }
            },
            "/jobs/{id}" => {
              get: {
                summary: "Get status and progress of a background job",
                operationId: "getJobStatus",
                parameters: [
                  { name: "id", in: "path", required: true, schema: { type: "string" } }
                ],
                responses: { "200" => { description: "Job status" } }
              }
            },
            "/settings" => {
              get: {
                summary: "Get platform embedding and LLM settings",
                operationId: "getSettings",
                responses: { "200" => { description: "Settings and statistics" } }
              }
            },
            "/settings/context_window" => {
              patch: {
                summary: "Update LLM context window",
                operationId: "updateContextWindow",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[context_window],
                        properties: {
                          context_window: { type: "integer", minimum: 4096 }
                        }
                      }
                    }
                  }
                },
                responses: { "200" => { description: "Updated context window" } }
              }
            },
            "/settings/generate_embeddings" => {
              post: {
                summary: "Enqueue bulk embedding generation",
                operationId: "generateAllEmbeddings",
                requestBody: {
                  required: true,
                  content: {
                    "application/json" => {
                      schema: {
                        type: "object",
                        required: %w[model_type],
                        properties: {
                          model_type: { type: "string", enum: %w[Species Organism] },
                          only_missing: { type: "boolean", default: true }
                        }
                      }
                    }
                  }
                },
                responses: { "202" => { description: "Job enqueued" } }
              }
            }
          }
        }
      end
    end
  end
end
