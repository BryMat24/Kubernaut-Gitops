| Category      | Test                          | Why                                   |
| ------------- | ----------------------------- | ------------------------------------- |
| Pod Lifecycle | CrashLoopBackOff              | Most common application failure       |
| Pod Lifecycle | ImagePullBackOff              | Common deployment issue               |
| Scheduling    | Pending (insufficient CPU)    | Demonstrates scheduler reasoning      |
| Scheduling    | Pending (taints/nodeSelector) | Shows configuration reasoning         |
| Networking    | Service selector mismatch     | Very common Kubernetes bug            |
| Networking    | DNS failure                   | Exercises service discovery           |
| Storage       | PVC Pending                   | Covers persistent storage failures    |
| Configuration | Missing ConfigMap             | Common startup/configuration issue    |
| Configuration | RBAC Forbidden                | Demonstrates permission diagnosis     |
| Resource      | OOMKilled                     | Uses Prometheus + Kubernetes evidence |
| Deployment    | Rollout stuck                 | Real-world deployment failure         |
| GitOps        | ArgoCD OutOfSync              | Demonstrates GitOps remediation       |
| Dependency    | Redis unavailable             | Shows dependency graph reasoning      |
| Dependency    | PostgreSQL unavailable        | Shows multi-hop diagnosis             |
