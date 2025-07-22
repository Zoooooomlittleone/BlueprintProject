# Docker Swarm Cluster Blueprint

**Last Updated:** March 30, 2025

## 1. CLUSTER OVERVIEW

### Architecture
This blueprint documents a Docker Swarm cluster with a star topology where a master node coordinates and manages multiple worker nodes of different types. The cluster is designed for flexibility with heterogeneous devices, including traditional servers, laptops, and mobile devices.

### Current Nodes
- **Master Node**: Pop OS server (192.168.0.200)
- **Worker Nodes**:
  - Optiplex70101 (192.168.0.202)
  - Optiplex70102 (192.168.0.203)
  - Lenovo Laptop (192.168.0.205, appears as "docker-desktop" in swarm)
  - Samsung A50 Mobile (configured via Termux)
  - HP Laptop (to be added)

### Network Configuration
- **Subnet**: 192.168.0.0/24
- **Master Node IP**: 192.168.0.200
- **Worker Node IPs**: See above
- **Services Network**: Overlay network created by Docker Swarm
- **Required Ports**:
  - 2377/tcp (swarm management)
  - 7946/tcp/udp (node communication)
  - 4789/udp (overlay network)

## 2. NODE SPECIFICATIONS

### Master Node
- **Hostname**: master
- **IP Address**: 192.168.0.200
- **Role**: Manager (Leader)
- **OS**: Pop OS
- **Docker Version**: 26.1.3
- **Hardware**: optiplex_780_1 (8 cores, 16GB RAM)

### Optiplex Worker Nodes
- **Hostname**: optiplex70101, optiplex70102
- **IP Addresses**: 192.168.0.202, 192.168.0.203
- **Role**: Worker
- **OS**: Linux (Debian-based)
- **Docker Version**: 26.1.3
- **Hardware**: 8 cores, 16GB RAM each

### Lenovo Laptop Node
- **Hostname**: cluster-node-205 (shows as "docker-desktop" in node list)
- **IP Address**: 192.168.0.205
- **Role**: Worker
- **OS**: Windows (Using Docker Desktop with WSL2)
- **Docker Version**: 4.39.0 (184744)
- **Configuration**:
  - Hosts file entry: 192.168.0.200 master
  - WSL2 backend for Docker Desktop
  - Appears as "docker-desktop" in swarm node list

### Samsung A50 Mobile Node
- **Role**: Mobile Worker Node
- **Configuration**:
  - Uses Termux app
  - SSH server on port 8022
  - Runs Docker through Ubuntu userspace in Termux
  - Specialized for network scanning and remote testing

### HP Laptop Node (Planned)
- **Role**: Worker
- **Status**: To be implemented
- **Configuration**: Will follow similar setup to Lenovo laptop

## 3. CORE CONFIGURATION

### Swarm Initialization
The swarm is initialized on the master node with:
```bash
docker swarm init --advertise-addr 192.168.0.200
```

### Joining Workers
Workers join the swarm using the join token:
```bash
docker swarm join --token SWMTKN-1-49uqsg7eoqeb3o02gc70so5u85phyqgd1c9iu4og703j5u6mwh-1z2s7z40c17eba5fv6e7x95do 192.168.0.200:2377
```

### Node Labels
All nodes receive appropriate labels for service constraints:
- Master: role=manager
- Optiplex workers: type=server
- Lenovo laptop: type=laptop
- Samsung mobile: type=mobile

### Power Management
The cluster includes scripts to handle power management:
- Sequential startup of nodes when master powers on
- Graceful shutdown of worker nodes when master shuts down
- Wake-on-LAN capability for supporting nodes

## 4. POWER MANAGEMENT SYSTEM

### Sequential Startup
When the master node powers on:
1. The startup script `/usr/local/bin/node_startup.sh` runs automatically
2. The script checks for available nodes on the network
3. Wake-on-LAN packets are sent to supported nodes
4. SSH connections are established to verify node status
5. Nodes are reintegrated into the swarm if necessary

### Graceful Shutdown
When the master node shuts down:
1. The shutdown script `/usr/local/bin/node_shutdown.sh` is triggered
2. Services are scaled down gracefully
3. Worker nodes are notified to prepare for shutdown
4. Critical data is backed up
5. Worker nodes shut down in sequence
6. Master node completes its shutdown

### Node Health Monitoring
- Continuous health checks are performed on all nodes
- Automated recovery procedures for disconnected nodes
- Alerting system for critical failures

## 5. SERVICE DEPLOYMENT

### Service Constraints
Services are deployed with specific constraints based on node capabilities:
- Computation-intensive services on Optiplex servers
- User interface services on Lenovo laptop
- Network scanning and testing on Samsung mobile
- Shared storage services on the master node

### Load Balancing
- Docker Swarm's built-in load balancing distributes requests
- Service replicas are distributed across appropriate nodes
- Health checks ensure requests only go to healthy containers

### Storage Configuration
- Persistent storage for databases and configuration
- Shared volumes for service coordination
- Backup system for critical data

## 6. MONITORING AND MANAGEMENT

### Visualization
- Swarm visualizer accessible at http://192.168.0.200:8080
- Shows real-time node status and container placement

### Monitoring Tools
- Node-level metrics collection
- Container resource usage monitoring
- Alert system for resource constraints
- Performance optimization based on collected metrics

### Management Scripts
- Central management from master node
- Remote execution capabilities
- Automated maintenance routines
- Recovery procedures for various failure scenarios

## 7. SECURITY CONSIDERATIONS

### Network Security
- Firewall configuration for all nodes
- Restricted access to swarm management ports
- Network encryption for overlay networks

### Authentication
- SSH key-based authentication (planned)
- Currently using password authentication
- Passwordless sudo access required on nodes

### Container Security
- Image scanning for vulnerabilities
- Principle of least privilege for containers
- Resource isolation between services

## 8. BACKUP AND RECOVERY

### Backup Strategy
- Regular automated backups of critical data
- Configuration snapshots
- Swarm state preservation

### Disaster Recovery
- Procedures for master node failure
- Worker node replacement process
- Full cluster reconstruction documentation

## 9. INTEGRATION POINTS

### CI/CD Integration
- Prepared for continuous deployment pipelines
- Service update methodology
- Rollback capabilities

### External Systems
- API endpoints for external monitoring
- Integration with notification systems
- Remote management capabilities

## 10. MAINTENANCE PROCEDURES

### Updates and Patches
- Rolling updates for services
- Node update procedure
- Swarm-aware update sequencing

### Performance Tuning
- Resource allocation guidelines
- Node optimization procedures
- Service scaling recommendations

## 11. IMPLEMENTATION PLAN FOR REMAINING NODES

### HP Laptop Integration
1. Prepare installation scripts similar to Lenovo laptop
2. Configure Docker Desktop with WSL2 backend
3. Add master node to hosts file
4. Join swarm with worker token
5. Apply appropriate node labels
6. Configure power management

### Additional Optimizations
1. Complete node scanning and verification system
2. Implement performance optimization across all nodes
3. Deploy monitoring dashboard
4. Conduct full system integration testing

## 12. KNOWN ISSUES & LIMITATIONS

1. SSH key-based authentication not fully implemented [MEDIUM]
   - Currently using password-based auth
   - Plan to implement key distribution system

2. Passwordless sudo access required on all nodes [HIGH]
   - Needed for power control and system optimization
   - Security implications to be addressed

3. Wake-on-LAN requires MAC address discovery [LOW]
   - Currently using ARP table lookup
   - May not work across subnets

4. Performance metrics not standardized [MEDIUM]
   - Need to establish baseline performance indicators
   - Implement consistent benchmarking methodology

## 13. FUTURE ENHANCEMENTS

1. Automated scaling based on resource usage
2. Enhanced security implementation
3. Integration with cloud resources
4. Containerized CI/CD pipeline
5. Advanced visualization and monitoring dashboard
