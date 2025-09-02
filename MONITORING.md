# Digital Freight Matching - Comprehensive Monitoring & Alerting

This document describes the comprehensive monitoring and alerting system implemented for the Digital Freight Matching platform.

## 🎯 Overview

The monitoring system provides:
- **Real-time Application Performance Monitoring (APM)**
- **Business Metrics Dashboard** 
- **Intelligent Alerting with Escalation Policies**
- **Mean Time to Resolution (MTTR) < 15 minutes**
- **99.9% System Uptime Monitoring**

## 🏗️ Architecture

### Core Components

1. **Metrics Collection**: Prometheus + Yabeda (Ruby)
2. **Visualization**: Grafana dashboards
3. **Alerting**: Alertmanager with multi-channel notifications
4. **Log Analysis**: ELK Stack (Elasticsearch, Logstash, Kibana)
5. **Tracing**: Jaeger for distributed tracing
6. **Uptime Monitoring**: Blackbox Exporter + Uptime Kuma

### Business Metrics Tracked

- **Load Matching Success Rate**: Real-time matching efficiency
- **Revenue Metrics**: Platform revenue, transaction volumes
- **User Engagement**: Active users, registrations, API usage
- **Carrier Performance**: Utilization rates, delivery times
- **SLA Compliance**: Response times, uptime, error rates

## 🚀 Quick Start

### 1. Start Monitoring Stack

```bash
# Start complete monitoring infrastructure
docker compose -f docker-compose.monitoring.yml up -d

# Or start specific services
docker compose -f docker-compose.monitoring.yml up -d prometheus grafana alertmanager
```

### 2. Access Dashboards

- **Grafana**: http://localhost:3001 (admin/admin123_changeme)
- **Prometheus**: http://localhost:9090
- **Alertmanager**: http://localhost:9093
- **Kibana**: http://localhost:5601
- **Jaeger**: http://localhost:16686

### 3. Metrics Endpoint

Application metrics are available at: http://localhost:3000/metrics

## 📊 Key Metrics & Alerts

### Application Performance
- API response times (P95, P99)
- Error rates and types
- Database query performance
- Background job processing

### Business KPIs
- Load posting rates
- Matching success rates  
- Revenue trends
- User engagement metrics

### SLA Monitoring
- **Response Time SLA**: P95 < 2.0s, P99 < 5.0s
- **Uptime SLA**: 99.9% availability
- **Error Rate SLA**: < 1% error rate
- **Matching SLA**: > 85% success rate

## 🔔 Alert Escalation

### Critical Business Alerts (Immediate)
- Revenue drops > 20%
- Load matching failure > 50%
- System downtime
- **Channels**: Email, Slack, SMS

### High Priority Warnings (5 min)
- SLA violations
- High error rates
- Performance degradation
- **Channels**: Email, Slack

### Standard Alerts (15 min)
- Resource utilization
- Minor service issues
- **Channels**: Email

## 🛠️ Configuration Files

### Core Configuration
- `backend/config/initializers/monitoring.rb` - Metrics definitions
- `backend/config/prometheus.yml` - Prometheus scraping config
- `backend/config/alert_rules.yml` - Alert thresholds and rules

### Infrastructure
- `docker-compose.monitoring.yml` - Complete monitoring stack
- `monitoring/alertmanager/alertmanager.yml` - Alert routing
- `monitoring/grafana/provisioning/` - Dashboard provisioning

## 📈 Business Metrics Collection

The system automatically collects business metrics every 5 minutes via `BusinessMetricsCollectionJob`:

```ruby
# Key metrics collected
- Active loads and shipments
- User engagement (logins, registrations)
- Revenue and transaction volumes
- Carrier utilization rates
- API performance metrics
```

## 🔧 Development

### Adding New Metrics

1. Define metrics in `backend/config/initializers/monitoring.rb`:
```ruby
Yabeda.configure do
  group :your_feature do
    counter :your_metric, comment: "Description"
  end
end
```

2. Track metrics in controllers using `Monitorable` concern:
```ruby
class YourController < ApplicationController
  include Monitorable
  
  def your_action
    Yabeda.your_feature.your_metric.increment
    # your code
  end
end
```

### Adding New Alerts

1. Add alert rules to `backend/config/alert_rules.yml`
2. Configure notification channels in `monitoring/alertmanager/alertmanager.yml`
3. Restart Prometheus and Alertmanager

## 🧪 Testing

### Validate Configuration
```bash
# Check Docker Compose syntax
docker compose -f docker-compose.monitoring.yml config

# Validate Prometheus config
docker run --rm -v $(pwd)/backend/config:/config prom/prometheus:latest promtool check config /config/prometheus.yml

# Validate alert rules
docker run --rm -v $(pwd)/backend/config:/config prom/prometheus:latest promtool check rules /config/alert_rules.yml
```

### Test Metrics Collection
```bash
# Check if metrics endpoint is working
curl http://localhost:3000/metrics

# Check specific business metrics
curl http://localhost:3000/api/v1/analytics/business_metrics
```

## 🔐 Environment Variables

Set these in `.env` file:

```bash
# Monitoring
MONITORING_ENABLED=true
GRAFANA_ADMIN_PASSWORD=your_secure_password

# Alert notifications
ONCALL_EMAIL=admin@yourcompany.com
BUSINESS_TEAM_EMAIL=business@yourcompany.com
SECURITY_TEAM_EMAIL=security@yourcompany.com
SLACK_WEBHOOK_URL=your_slack_webhook_url
```

## 🎯 Success Metrics

- ✅ **MTTR < 15 minutes**: Automated alerting enables rapid response
- ✅ **99.9% Uptime**: Comprehensive monitoring ensures high availability
- ✅ **Real-time Business Insights**: Live dashboards for all stakeholders
- ✅ **Proactive Issue Detection**: Anomaly detection prevents outages
- ✅ **Comprehensive Coverage**: Application, business, and infrastructure metrics

## 📚 Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Yabeda Ruby Gem](https://github.com/yabeda-rb/yabeda)
- [Alert Best Practices](https://prometheus.io/docs/practices/alerting/)

## 🆘 Troubleshooting

### Common Issues

1. **Metrics not appearing**: Check `MONITORING_ENABLED=true` in environment
2. **Alerts not firing**: Verify Prometheus can reach application `/metrics` endpoint
3. **Grafana can't connect**: Ensure Prometheus service is running and accessible
4. **Business metrics missing**: Check if background job `BusinessMetricsCollectionJob` is running

### Debug Commands
```bash
# Check metrics collection status
docker compose exec freight_api rails runner "BusinessMetricsCollector.collect_all_metrics"

# Verify Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check Grafana data sources  
curl -u admin:admin123_changeme http://localhost:3001/api/datasources
```