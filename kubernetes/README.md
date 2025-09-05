# Kubernetes Manifests for Digital Freight Matching Platform

This directory contains Kubernetes manifests for deploying the Digital Freight Matching Platform with resource optimization and auto-scaling capabilities.

## Overview

The Kubernetes deployment is designed to:
- **Reduce infrastructure costs by 40%** through right-sized resource allocation
- **Auto-scale based on CPU/memory metrics** using Horizontal Pod Autoscaler (HPA)
- **Maintain 99.9% uptime** during scaling events
- **Achieve container startup time < 30 seconds**
- **Provide comprehensive monitoring** and alerting

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                       │
├─────────────────────────────────────────────────────────────┤
│  Ingress Controller  │  Load Balancer  │  TLS Termination   │
├─────────────────────────────────────────────────────────────┤
│  Freight API (2-10 pods)  │  Sidekiq Workers (1-5 pods)    │
│  - CPU: 250m-1000m        │  - CPU: 100m-500m              │
│  - Memory: 256Mi-1Gi      │  - Memory: 128Mi-512Mi         │
├─────────────────────────────────────────────────────────────┤
│  PostgreSQL StatefulSet   │  Redis Deployment              │
│  - CPU: 250m-1000m        │  - CPU: 100m-500m              │
│  - Memory: 256Mi-1Gi      │  - Memory: 64Mi-256Mi          │
└─────────────────────────────────────────────────────────────┘
```

## Files Description

| File | Description |
|------|-------------|
| `00-namespace.yaml` | Namespace, ConfigMap, and Secrets |
| `01-freight-api.yaml` | Main API deployment and service |
| `02-hpa.yaml` | Horizontal Pod Autoscaler configurations |
| `03-freight-sidekiq.yaml` | Background job worker deployment |
| `04-database-services.yaml` | PostgreSQL and Redis deployments |
| `05-monitoring.yaml` | ServiceMonitor and PrometheusRule for monitoring |
| `06-ingress.yaml` | Ingress and LoadBalancer services |
| `07-resource-policies.yaml` | PodDisruptionBudgets, ResourceQuota, LimitRange |

## Resource Optimization

### CPU and Memory Allocation

| Component | Requests | Limits | Replicas (Min-Max) |
|-----------|----------|--------|-------------------|
| Freight API | 250m CPU, 256Mi RAM | 1000m CPU, 1Gi RAM | 2-10 |
| Sidekiq Workers | 100m CPU, 128Mi RAM | 500m CPU, 512Mi RAM | 1-5 |
| PostgreSQL | 250m CPU, 256Mi RAM | 1000m CPU, 1Gi RAM | 1 |
| Redis | 100m CPU, 64Mi RAM | 500m CPU, 256Mi RAM | 1 |

### Auto-scaling Triggers

- **Scale Up**: CPU > 70% or Memory > 80%
- **Scale Down**: CPU < 50% and Memory < 60% (with 5-minute stabilization)
- **Maximum Scale Rate**: 50% increase every 30 seconds
- **Maximum Scale Down Rate**: 10% decrease every 60 seconds

## Deployment Instructions

### Prerequisites

1. **Kubernetes cluster** (v1.25+) with:
   - Metrics Server installed
   - Prometheus Operator (for monitoring)
   - Cert-Manager (for TLS certificates)
   - Ingress Controller (NGINX recommended)

2. **Storage Class**: Configure `fast-ssd` storage class for PostgreSQL

3. **Secrets**: Update base64-encoded secrets in `00-namespace.yaml`

### Deployment Steps

1. **Deploy namespace and configuration**:
   ```bash
   kubectl apply -f 00-namespace.yaml
   ```

2. **Deploy database services**:
   ```bash
   kubectl apply -f 04-database-services.yaml
   ```

3. **Wait for database readiness**:
   ```bash
   kubectl wait --for=condition=ready pod -l app=postgres -n digital-freight-matching --timeout=300s
   kubectl wait --for=condition=ready pod -l app=redis -n digital-freight-matching --timeout=300s
   ```

4. **Deploy application services**:
   ```bash
   kubectl apply -f 01-freight-api.yaml
   kubectl apply -f 03-freight-sidekiq.yaml
   ```

5. **Enable auto-scaling**:
   ```bash
   kubectl apply -f 02-hpa.yaml
   ```

6. **Configure monitoring**:
   ```bash
   kubectl apply -f 05-monitoring.yaml
   ```

7. **Set up ingress and policies**:
   ```bash
   kubectl apply -f 06-ingress.yaml
   kubectl apply -f 07-resource-policies.yaml
   ```

### Verification

1. **Check deployment status**:
   ```bash
   kubectl get pods -n digital-freight-matching
   kubectl get hpa -n digital-freight-matching
   ```

2. **Monitor resource usage**:
   ```bash
   kubectl top pods -n digital-freight-matching
   kubectl top nodes
   ```

3. **Test auto-scaling**:
   ```bash
   # Generate load to trigger scaling
   kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh
   # Inside the pod, run: while true; do wget -q -O- http://freight-api.digital-freight-matching.svc.cluster.local:3000/health; done
   ```

## Monitoring and Alerting

### Key Metrics Monitored

- **SLA Metrics**: Response time (P95 < 2s, P99 < 5s), uptime (99.9%), error rate (<1%)
- **Resource Metrics**: CPU usage, memory usage, disk I/O, network I/O
- **Business Metrics**: Request throughput, queue depth, database connections
- **Cost Metrics**: Resource utilization efficiency, scaling events

### Alert Thresholds

| Alert | Threshold | Severity |
|-------|-----------|----------|
| High Error Rate | >5% for 5 minutes | Warning |
| High Latency | P95 >2s for 5 minutes | Warning |
| High CPU Usage | >80% for 10 minutes | Warning |
| High Memory Usage | >90% for 5 minutes | Critical |
| Large Queue Backlog | >1000 jobs for 5 minutes | Warning |

## Cost Optimization Features

1. **Right-sized Resources**: Carefully tuned CPU and memory requests/limits
2. **Efficient Auto-scaling**: Conservative scale-down, responsive scale-up
3. **Resource Quotas**: Prevent resource waste and runaway scaling
4. **Pod Disruption Budgets**: Ensure availability during node maintenance
5. **Monitoring-driven Optimization**: Continuous monitoring for further optimization

## Security Considerations

- All secrets stored in Kubernetes Secrets (use external secret management in production)
- Network policies to restrict inter-pod communication
- Resource limits to prevent resource exhaustion attacks
- Regular security scanning of container images
- TLS encryption for all external traffic

## Troubleshooting

### Common Issues

1. **Pods not starting**: Check resource availability and limits
   ```bash
   kubectl describe pod <pod-name> -n digital-freight-matching
   ```

2. **HPA not scaling**: Verify metrics server is running
   ```bash
   kubectl top pods -n digital-freight-matching
   ```

3. **Database connection issues**: Check service discovery and network policies
   ```bash
   kubectl get svc -n digital-freight-matching
   kubectl get endpoints -n digital-freight-matching
   ```

## Performance Benchmarks

### Target Metrics
- **Container Startup Time**: <30 seconds
- **API Response Time**: P95 <2s, P99 <5s
- **System Uptime**: 99.9%
- **Cost Reduction**: 40% compared to over-provisioned setup
- **Scaling Speed**: 50% scale-up in 30 seconds, 10% scale-down in 60 seconds

### Load Testing
Use tools like `k6` or `Apache Bench` to validate performance:
```bash
# Example load test
k6 run --vus 100 --duration 5m load-test.js
```

For detailed monitoring setup, see the main project's `MONITORING.md` file.