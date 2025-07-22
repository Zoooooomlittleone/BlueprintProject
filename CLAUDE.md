# Docker Swarm Cluster - Claude Configuration

## Project Overview
This is a production-ready Docker Swarm cluster with automated health checks, self-healing, and monitoring.

## Key Information
- **Cluster**: 4 nodes (master + 3 workers)
- **Services**: 14 production services running
- **IPs**: Master: 192.168.0.200, Workers: .201, .202, .203
- **Automation**: Health checks every 15 min, self-healing hourly, backups at 2 AM

## Available Tools
- Docker commands via Desktop Commander MCP
- File operations via Filesystem MCP
- Web search for documentation
- Git operations (once GitHub MCP is configured)

## Common Commands
```bash
# Check cluster status
docker node ls
docker service ls

# View logs
docker service logs <service-name>

# Scale services
docker service scale <service>=<replicas>

# Check automation
sudo crontab -l | grep swarm
```

## Project Structure
```
~/Desktop/BlueprintProject/
├── scripts/automation/
│   ├── healthchecks/
│   ├── backups/
│   └── loadbalancing/
├── backups/
├── logs/
├── docs/
└── [configuration files]
```

## Current Priorities
1. Add laptop/mobile nodes to cluster
2. Deploy containerized applications
3. Set up GitLab CI/CD
4. Configure SSL/TLS with Traefik

## Web Interfaces
- Swarmpit: http://192.168.0.200:888
- Grafana: http://192.168.0.200:3000
- Prometheus: http://192.168.0.200:9090
- Visualizer: http://192.168.0.200:8080

## GitHub Repository
https://github.com/Zoooooomlittleone/BlueprintProject

## Security Notes
- Docker API exposed on port 2375 (firewall protected)
- All scripts require sudo for critical operations
- Backups stored locally (consider offsite backup)

## Custom Commands
When using claude-cmd, useful commands for this project:
- `docker-status`: Check all services and nodes
- `backup-now`: Run manual backup
- `health-check`: Force health check
- `add-node`: Wizard to add new node
