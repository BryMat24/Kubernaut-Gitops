| Category            | Recommended scenario            |
| ------------------- | ------------------------------- |
| Pod Lifecycle       | CrashLoopBackOff                |
| Pod Lifecycle       | ImagePullBackOff                |
| Scheduling          | Pending (Insufficient CPU)      |
| Networking          | Service selector mismatch       |
| Configuration       | Missing ConfigMap               |
| Resource Management | OOMKilled                       |
| Dependency          | Backend cannot reach Redis      |
| GitOps              | Generate PR to fix image/config |
