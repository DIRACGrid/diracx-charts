---
config:
  layout: elk
---
flowchart TD

    subgraph k8s_instance ["K8s Instance: diracx"]
        subgraph helm_chart ["Helm Chart: diracx 1.1.0"]
            subgraph k8s_app ["K8s Application: diracx"]
                ing_diracx{{"ing: diracx"}}
                svc_diracx(("svc: diracx"))
                svc_diracx_task_redis(("svc: diracx-task-redis"))
                svc_diracx_web(("svc: diracx-web"))
                deploy_diracx["deploy: diracx"]
                deploy_diracx_task_worker_large["deploy: diracx-task-worker-large"]
                deploy_diracx_task_worker_medium["deploy: diracx-task-worker-medium"]
                deploy_diracx_task_worker_small["deploy: diracx-task-worker-small"]
                deploy_diracx_web["deploy: diracx-web"]
                sts_diracx_task_redis["sts: diracx-task-redis"]
                sts_diracx_task_scheduler["sts: diracx-task-scheduler"]
                cronjob_diracx_cleanup_authdb(["cronjob: diracx-cleanup-authdb"])
                cm_diracx_cleanup_authdb[("cm: diracx-cleanup-authdb")]
                cm_mysql_init_diracx_dbs[("cm: mysql-init-diracx-dbs")]
                secret_diracx_secrets>"secret: diracx-secrets"]
                sa_diracx[["sa: diracx"]]
            end

            subgraph hook_post_install_pre_upgrade ["post-install,pre-upgrade"]
                cm_diracx_validate_config[("cm: diracx-validate-config")]
                job_diracx_validate_config(["job: diracx-validate-config"])
                secret_diracx_validate_config_secrets>"secret: diracx-validate-config-secrets"]
            end

            subgraph hook_pre_install ["pre-install"]
                cm_diracx_init_keystore[("cm: diracx-init-keystore")]
                job_diracx_init_keystore(["job: diracx-init-keystore"])
            end

            subgraph hook_pre_install_pre_upgrade ["pre-install,pre-upgrade"]
                cm_diracx_container_entrypoint[("cm: diracx-container-entrypoint")]
            end
        end
    end

    %% Relationships
    svc_diracx_web -->|"routes to"| deploy_diracx_web
    svc_diracx -->|"routes to"| deploy_diracx
    svc_diracx_task_redis -->|"routes to"| sts_diracx_task_redis
    ing_diracx -->|"/api"| svc_diracx
    ing_diracx -->|"/.well-known"| svc_diracx
    ing_diracx -->|"/"| svc_diracx_web
    deploy_diracx_web -->|"uses"| sa_diracx
    deploy_diracx -->|"mounts"| cm_diracx_container_entrypoint
    deploy_diracx -->|"env"| secret_diracx_secrets
    deploy_diracx -->|"uses"| sa_diracx
    deploy_diracx_task_worker_small -->|"mounts"| cm_diracx_container_entrypoint
    deploy_diracx_task_worker_small -->|"env"| secret_diracx_secrets
    deploy_diracx_task_worker_small -->|"uses"| sa_diracx
    deploy_diracx_task_worker_medium -->|"mounts"| cm_diracx_container_entrypoint
    deploy_diracx_task_worker_medium -->|"env"| secret_diracx_secrets
    deploy_diracx_task_worker_medium -->|"uses"| sa_diracx
    deploy_diracx_task_worker_large -->|"mounts"| cm_diracx_container_entrypoint
    deploy_diracx_task_worker_large -->|"env"| secret_diracx_secrets
    deploy_diracx_task_worker_large -->|"uses"| sa_diracx
    sts_diracx_task_redis -->|"uses"| sa_diracx
    sts_diracx_task_scheduler -->|"mounts"| cm_diracx_container_entrypoint
    sts_diracx_task_scheduler -->|"env"| secret_diracx_secrets
    sts_diracx_task_scheduler -->|"uses"| sa_diracx
    job_diracx_init_keystore -->|"mounts"| cm_diracx_init_keystore
    job_diracx_init_keystore -->|"mounts"| cm_diracx_container_entrypoint
    job_diracx_validate_config -->|"mounts"| cm_diracx_validate_config
    job_diracx_validate_config -->|"mounts"| cm_diracx_container_entrypoint
    job_diracx_validate_config -->|"env"| secret_diracx_validate_config_secrets
    cronjob_diracx_cleanup_authdb -->|"mounts"| cm_diracx_cleanup_authdb
    cronjob_diracx_cleanup_authdb -->|"mounts"| cm_diracx_container_entrypoint
    cronjob_diracx_cleanup_authdb -->|"env"| secret_diracx_secrets

    %% Styling
    classDef ing fill:#4a90d9,stroke:#2563eb,color:#ffffff
    classDef svc fill:#5ba3e6,stroke:#2563eb,color:#ffffff
    classDef deploy fill:#3b7dd8,stroke:#2563eb,color:#ffffff
    classDef sts fill:#3b7dd8,stroke:#2563eb,color:#ffffff
    classDef job fill:#6db3f2,stroke:#2563eb,color:#1a1a2e
    classDef cronjob fill:#6db3f2,stroke:#2563eb,color:#1a1a2e
    classDef cm fill:#7ec8e3,stroke:#2563eb,color:#1a1a2e
    classDef secret fill:#a78bfa,stroke:#2563eb,color:#ffffff
    classDef sa fill:#94a3b8,stroke:#2563eb,color:#ffffff
    class cm_diracx_cleanup_authdb cm
    class cm_diracx_container_entrypoint cm
    class cm_diracx_init_keystore cm
    class cm_diracx_validate_config cm
    class cm_mysql_init_diracx_dbs cm
    class cronjob_diracx_cleanup_authdb cronjob
    class deploy_diracx deploy
    class deploy_diracx_task_worker_large deploy
    class deploy_diracx_task_worker_medium deploy
    class deploy_diracx_task_worker_small deploy
    class deploy_diracx_web deploy
    class ing_diracx ing
    class job_diracx_init_keystore job
    class job_diracx_validate_config job
    class secret_diracx_secrets secret
    class secret_diracx_validate_config_secrets secret
    class svc_diracx svc
    class svc_diracx_task_redis svc
    class svc_diracx_web svc
    class sa_diracx sa
    class sts_diracx_task_redis sts
    class sts_diracx_task_scheduler sts
    style k8s_instance fill:none,stroke:#60a5fa,stroke-width:2px,color:#60a5fa
    style helm_chart fill:none,stroke:#93c5fd,stroke-width:1px,stroke-dasharray:5 5,color:#93c5fd
    style k8s_app fill:#3b82f610,stroke:#3b82f6,stroke-width:1px,color:#3b82f6
    style hook_post_install_pre_upgrade fill:#10b98110,stroke:#10b981,stroke-width:1px,color:#10b981
    style hook_pre_install fill:#10b98110,stroke:#10b981,stroke-width:1px,color:#10b981
    style hook_pre_install_pre_upgrade fill:#10b98110,stroke:#10b981,stroke-width:1px,color:#10b981
